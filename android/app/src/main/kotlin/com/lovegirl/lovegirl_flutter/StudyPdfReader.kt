package com.lovegirl.lovegirl_flutter

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FilterInputStream
import java.io.IOException
import java.io.InputStream
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.max
import kotlin.math.roundToInt

internal class StudyPdfReader(private val activity: Activity) {
    companion object {
        const val PICK_REQUEST = 20471
        private const val MAX_FILE = 256L * 1024 * 1024
        private const val MAX_RANGE = 16
        private val idPattern = Regex("[a-f0-9-]{36}")
    }

    private val resolver get() = activity.contentResolver
    private val documents by lazy { activity.getSharedPreferences("study_pdf_documents", Activity.MODE_PRIVATE) }
    private val executor = Executors.newSingleThreadExecutor()
    private var pending: Pair<Int, MethodChannel.Result>? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val account = call.argument<Int>("account")
        if (account == null || account <= 0) {
            result.error("STUDY_PDF_ACCOUNT", "请重新登录后导入", null)
            return
        }
        if (call.method == "pickStudyPdf") {
            if (pending != null) {
                result.error("STUDY_PDF_BUSY", "文件选择器已打开", null)
                return
            }
            pending = account to result
            try {
                @Suppress("DEPRECATION")
                activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "application/pdf"
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                }, PICK_REQUEST)
            } catch (_: Exception) {
                pending = null
                result.error("STUDY_PDF_PICK", "暂时无法打开文件选择器", null)
            }
            return
        }

        val id = call.argument<String>("id")
        val first = call.argument<Int>("first") ?: 0
        val last = call.argument<Int>("last") ?: first
        val stored = id?.takeIf(idPattern::matches)?.let { documents.getString("$account:$it", null) }
        if (stored == null || first < 1 || last < first || last - first >= MAX_RANGE) {
            result.error("STUDY_PDF_MISSING", "请重新选择 PDF 或核对页码", null)
            return
        }
        val uri = Uri.parse(stored)
        run(result) {
            if (call.method == "previewStudyPdf") {
                withRenderer(uri) { renderer ->
                    renderer.openPage(first - 1).use { page ->
                        val bitmap = render(page, if (call.argument<Boolean>("forOcr") == true) 2200 else 1360)
                        try {
                            ByteArrayOutputStream().use { buffer ->
                                bitmap.compress(Bitmap.CompressFormat.JPEG, 88, buffer)
                                buffer.toByteArray()
                            }
                        } finally {
                            bitmap.recycle()
                        }
                    }
                }
            } else {
                read(uri, first, last, call.argument<Boolean>("forceOcr") == true,
                    call.argument<Boolean>("answerGrid") == true)
            }
        }
    }

    fun finishPick(code: Int, data: Intent?) {
        val (account, result) = pending ?: return
        pending = null
        val uri = data?.data
        if (code != Activity.RESULT_OK || uri?.scheme != "content") {
            result.success(null)
            return
        }
        try {
            resolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (_: SecurityException) {
            // Some providers grant access only for the current session.
        }
        run(result) {
            var name = "讲义.pdf"
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        name = cursor.getString(0)?.takeIf { it.isNotBlank() }?.take(160) ?: name
                        if (!cursor.isNull(1) && cursor.getLong(1) > MAX_FILE) throw PdfTooLarge()
                    }
                }
            val pages = withRenderer(uri) { it.pageCount }
            if (pages == 0) throw IOException("empty PDF")
            val prefix = "$account:"
            val key = documents.all.entries.firstOrNull { (key, value) ->
                key.startsWith(prefix) && value == uri.toString()
            }?.key ?: "$prefix${UUID.randomUUID()}"
            documents.edit().putString(key, uri.toString()).apply()
            mapOf("id" to key.substringAfter(':'), "name" to name, "pages" to pages)
        }
    }

    private fun run(result: MethodChannel.Result, operation: () -> Any) {
        executor.execute {
            try {
                val value = operation()
                activity.runOnUiThread { result.success(value) }
            } catch (_: PdfTooLarge) {
                activity.runOnUiThread { result.error("STUDY_PDF_SIZE", "请选择不超过 256 MB 的 PDF", null) }
            } catch (_: SecurityException) {
                activity.runOnUiThread { result.error("STUDY_PDF_ACCESS", "PDF 无法打开，请检查权限或选择无密码副本", null) }
            } catch (_: Exception) {
                activity.runOnUiThread { result.error("STUDY_PDF_READ", "PDF 暂时无法读取，请核对文件和页码", null) }
            }
        }
    }

    private fun read(uri: Uri, first: Int, last: Int, forceOcr: Boolean, answerGrid: Boolean): List<Map<String, Any>> {
        val embedded = if (forceOcr) emptyMap() else extractText(uri, first, last)
        val recognizer = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
        try {
            return withRenderer(uri) { renderer ->
                require(last <= renderer.pageCount)
                (first..last).map { number ->
                    val text = embedded[number].orEmpty()
                    if (usable(text)) {
                        mapOf("number" to number, "text" to text)
                    } else {
                        val raster = renderer.openPage(number - 1).use { render(it, 2440) }
                        try {
                            raiseTextContrast(raster)
                            val result = Tasks.await(recognizer.process(InputImage.fromBitmap(raster, 0)), 35, TimeUnit.SECONDS)
                            val lines = result.textBlocks.flatMap { block -> block.lines }.flatMap { line ->
                                val fragments = if (answerGrid) line.elements.map { it.text to it.boundingBox }
                                    else listOf(line.text to line.boundingBox)
                                fragments.mapNotNull { (text, box) -> box?.let {
                                    mapOf("text" to text, "x" to box.left, "y" to box.centerY(), "height" to box.height())
                                } }
                            }
                            var pageLines: List<Map<String, Any>> = lines
                            if (answerGrid) {
                                val grid = StudyAnswerGrid.tryRead(raster)
                                if (grid != null) {
                                    try {
                                        val compact = Tasks.await(recognizer.process(InputImage.fromBitmap(grid.image, 0)), 20, TimeUnit.SECONDS)
                                    val matched = grid.pairedRows(result, compact)
                                        if (matched.isNotEmpty()) {
                                            // Use coordinates from the grid for small cells which full-page OCR can skip.
                                            // Retain Chinese section headers so single/multiple choice still stay separate.
                                            pageLines = lines.filter { line ->
                                                !grid.contains(line["y"] as Int) ||
                                                    (line["text"] as String).any { it in '\u3400'..'\u9fff' }
                                            } + matched
                                        }
                                    } catch (_: Exception) {
                                        // The whole-page OCR result remains available if grid analysis fails.
                                    } finally {
                                        grid.image.recycle()
                                    }
                                }
                            }
                            mapOf("number" to number, "text" to result.text.take(36000), "lines" to pageLines)
                        } finally {
                            raster.recycle()
                        }
                    }
                }
            }
        } finally {
            recognizer.close()
        }
    }

    private fun extractText(uri: Uri, first: Int, last: Int): Map<Int, String> {
        PDFBoxResourceLoader.init(activity.applicationContext)
        val memory = MemoryUsageSetting.setupMixed(12L * 1024 * 1024, 536870912L).setTempDir(activity.cacheDir)
        return try {
            input(uri).use { input ->
                PDDocument.load(input, memory).use { pdf ->
                    val stripper = PDFTextStripper().apply { sortByPosition = true }
                    (first..minOf(last, pdf.numberOfPages)).associateWith { page ->
                        stripper.startPage = page
                        stripper.endPage = page
                        stripper.getText(pdf).trim().take(36000)
                    }
                }
            }
        } catch (error: PdfTooLarge) {
            throw error
        } catch (_: IOException) {
            emptyMap()
        }
    }

    // A text layer can be only the same watermark repeated across an image scan.
    private fun usable(text: String): Boolean {
        val compact = text.filter { it.isLetterOrDigit() }
        return compact.length >= 42 && compact.windowed(2).toSet().size >= 24
    }

    private fun raiseTextContrast(bitmap: Bitmap) {
        // Very pale watermarks and colored cell fills are common on scanned handouts.
        // Keep dark print, including red answer-table numerals, and lift pale marks.
        val row = IntArray(bitmap.width)
        for (y in 0 until bitmap.height) {
            bitmap.getPixels(row, 0, row.size, 0, y, row.size, 1)
            for (x in row.indices) {
                val pixel = row[x]
                val luma = (Color.red(pixel) * 77 + Color.green(pixel) * 150 + Color.blue(pixel) * 29) shr 8
                val ink = ((luma - 105) * 255 / 89).coerceIn(0, 255)
                row[x] = Color.rgb(ink, ink, ink)
            }
            bitmap.setPixels(row, 0, row.size, 0, y, row.size, 1)
        }
    }

    private fun render(page: PdfRenderer.Page, longest: Int): Bitmap {
        val scale = longest.toFloat() / max(page.width, page.height).coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap((page.width * scale).roundToInt().coerceAtLeast(1),
            (page.height * scale).roundToInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        try {
            bitmap.eraseColor(Color.WHITE)
            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            return bitmap
        } catch (error: Exception) {
            bitmap.recycle()
            throw error
        }
    }

    private fun input(uri: Uri): InputStream = LimitedInput(resolver.openInputStream(uri) ?: throw IOException("missing PDF"))

    private fun <T> withRenderer(uri: Uri, operation: (PdfRenderer) -> T): T {
        val descriptor = resolver.openFileDescriptor(uri, "r") ?: throw IOException("missing PDF")
        val renderer = try {
            PdfRenderer(descriptor)
        } catch (_: IllegalArgumentException) {
            // Providers may return a pipe rather than a seekable descriptor.
            descriptor.close()
            val copy = File.createTempFile("study-pdf-", ".pdf", activity.cacheDir)
            try {
                input(uri).use { source -> copy.outputStream().use { source.copyTo(it) } }
                val local = ParcelFileDescriptor.open(copy, ParcelFileDescriptor.MODE_READ_ONLY)
                val fallback = try { PdfRenderer(local) } catch (error: Exception) {
                    local.close()
                    throw error
                }
                return fallback.use(operation)
            } finally {
                copy.delete()
            }
        } catch (error: Exception) {
            descriptor.close()
            throw error
        }
        return renderer.use(operation)
    }

    private class PdfTooLarge : IOException()

    private class LimitedInput(source: InputStream) : FilterInputStream(source) {
        private var consumed = 0L
        private fun record(bytes: Int) {
            if (bytes > 0) consumed += bytes
            if (consumed > MAX_FILE) throw PdfTooLarge()
        }
        override fun read(): Int = super.read().also { if (it >= 0) record(1) }
        override fun read(bytes: ByteArray, offset: Int, count: Int): Int =
            super.read(bytes, offset, count).also(::record)
    }
}
