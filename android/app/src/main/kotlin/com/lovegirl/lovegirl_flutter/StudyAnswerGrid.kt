package com.lovegirl.lovegirl_flutter

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import com.google.mlkit.vision.text.Text
import kotlin.math.min
import kotlin.math.roundToInt

internal class StudyAnswerGrid private constructor(
    val image: Bitmap,
    private val x: List<Int>,
    private val y: List<Int>
) {
    companion object {
        private const val CELL_WIDTH = 106
        private const val CELL_HEIGHT = 58
        private val number = Regex("[1-9]\\d{0,2}")
        private val choices = Regex("[A-D]{1,4}")

        fun tryRead(page: Bitmap): StudyAnswerGrid? {
            val width = page.width
            val height = page.height
            val pixels = IntArray(width * height)
            page.getPixels(pixels, 0, width, 0, 0, width, height)
            fun dark(offset: Int) = Color.red(pixels[offset]) < 130
            val horizontal = mutableListOf<Int>()
            var left = 0
            var right = 0
            var longest = 0
            for (row in 0 until height) {
                var run = 0
                for (column in 0 until width) {
                    if (dark(row * width + column)) {
                        run++
                        if (run > longest) {
                            longest = run
                            left = column + 1 - run
                            right = column + 1
                        }
                        if (run == (width * .43).toInt()) horizontal.add(row)
                    } else {
                        run = 0
                    }
                }
            }
            val rows = centers(horizontal)
            if (rows.size !in 5..29) return null
            val top = rows.first()
            val bottom = rows.last()
            if (bottom - top < height / 5) return null
            val vertical = (left..min(right, width - 1)).filter { column ->
                (top until bottom step 2).count { row -> dark(row * width + column) } > (bottom - top) * .24
            }
            val columns = centers(vertical)
            if (columns.size !in 3..9 || columns.zipWithNext().any { (a, b) -> b - a < 30 }) return null

            // Repack the individual cells so OCR sees compact rows with readable isolated letters.
            val cleaned = Bitmap.createBitmap((columns.size - 1) * CELL_WIDTH,
                (rows.size - 1) * CELL_HEIGHT, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(cleaned).apply { drawColor(Color.WHITE) }
            val paint = Paint(Paint.FILTER_BITMAP_FLAG)
            rows.zipWithNext().forEachIndexed { row, (start, end) ->
                if (end - start < 19) return@forEachIndexed
                columns.zipWithNext().forEachIndexed columnLoop@{ column, (a, b) ->
                    val cell = Rect(a + 5, start + 4, b - 5, end - 4)
                    var minX = cell.right
                    var maxX = cell.left
                    var minY = cell.bottom
                    var maxY = cell.top
                    for (py in cell.top until cell.bottom) {
                        for (px in cell.left until cell.right) {
                            if (dark(py * width + px)) {
                                minX = min(minX, px)
                                maxX = maxOf(maxX, px)
                                minY = min(minY, py)
                                maxY = maxOf(maxY, py)
                            }
                        }
                    }
                    val inkWidth = maxX - minX + 1
                    val inkHeight = maxY - minY + 1
                    if (inkWidth < 3 || inkHeight < 7 || inkWidth > cell.width() * .86) return@columnLoop
                    val scale = minOf(1.9f, 34f / inkHeight, 88f / inkWidth)
                    val destWidth = (inkWidth * scale).roundToInt()
                    val destHeight = (inkHeight * scale).roundToInt()
                    val destX = column * CELL_WIDTH + 8
                    val destY = row * CELL_HEIGHT + (CELL_HEIGHT - destHeight) / 2
                    canvas.drawBitmap(page, Rect(minX, minY, maxX + 1, maxY + 1),
                        Rect(destX, destY, destX + destWidth, destY + destHeight), paint)
                }
            }
            return StudyAnswerGrid(cleaned, columns, rows)
        }

        private fun centers(points: List<Int>): List<Int> {
            if (points.isEmpty()) return emptyList()
            val groups = mutableListOf<Int>()
            var first = points.first()
            var last = first
            for (value in points.drop(1)) {
                if (value - last > 3) {
                    groups.add((first + last) / 2)
                    first = value
                }
                last = value
            }
            groups.add((first + last) / 2)
            return groups
        }
    }

    fun contains(yPosition: Int) = yPosition in y.first()..y.last()

    private fun readCells(text: Text, columns: List<Int>, rows: List<Int>): Map<Pair<Int, Int>, String> {
        val cells = mutableMapOf<Pair<Int, Int>, MutableList<Pair<Int, String>>>()
        text.textBlocks.flatMap { it.lines }.flatMap { it.elements }.forEach { element ->
            val box = element.boundingBox ?: return@forEach
            val row = rows.indexOfFirst { it > box.centerY() } - 1
            val column = columns.indexOfFirst { it > box.left } - 1
            if (row < 0 || column < 0 || box.right > columns[column + 1]) return@forEach
            cells.getOrPut(row to column) { mutableListOf() }.add(box.left to element.text.uppercase())
        }
        return cells.mapValues { (_, fragments) -> fragments.sortedBy { it.first }.joinToString("") { it.second } }
    }

    fun pairedRows(original: Text, compact: Text): List<Map<String, Any>> {
        val originalCells = readCells(original, x, y)
        val compactCells = readCells(compact, x.indices.map { it * CELL_WIDTH }, y.indices.map { it * CELL_HEIGHT })
        fun at(row: Int, column: Int, pattern: Regex): String? {
            val cell = row to column
            val originalValue = originalCells[cell]?.takeIf(pattern::matches)
            val compactValue = compactCells[cell]?.takeIf(pattern::matches)
            if (originalValue != null && compactValue != null && originalValue != compactValue) return null
            return originalValue ?: compactValue
        }
        return (0 until y.size - 2).mapNotNull { row ->
            val pairs = (0 until x.size - 1).mapNotNull { column ->
                val ordinal = at(row, column, number)
                val answer = at(row + 1, column, choices)
                if (ordinal != null && answer != null) "$ordinal $answer" else null
            }
            if (pairs.isEmpty()) null else mapOf("text" to pairs.joinToString("  "),
                "x" to x.first(), "y" to (y[row + 1] + y[row + 2]) / 2, "height" to 20)
        }
    }
}
