import 'package:flutter/material.dart';

enum PaperMaterial {
  classic,
  carbon,
  cotton,
  linen,
  pearl,
  frost,
  blueSplit,
  sageEdge,
  roseCorner,
  peelWhite,
  peelBlack,
  clear,
  silver,
  film,
  letter,
  postmark,
  archive,
  tape,
  wave,
  fold,
}

class PaperTemplate {
  final String id;
  final String label;
  final PaperMaterial material;
  final Color color;
  final Color ink;
  const PaperTemplate(this.id, this.label, this.material, this.color,
      [this.ink = const Color(0xff202126)]);
}

const paperTemplates = [
  PaperTemplate('classic', '经典白', PaperMaterial.classic, Color(0xfffafafa)),
  PaperTemplate('carbon', '炭黑', PaperMaterial.carbon, Color(0xff292a2e),
      Color(0xfff6f6f6)),
  PaperTemplate('cotton', '棉纸', PaperMaterial.cotton, Color(0xfff8f8f5)),
  PaperTemplate('linen', '织纹', PaperMaterial.linen, Color(0xffeeeef0)),
  PaperTemplate('pearl', '珠光', PaperMaterial.pearl, Color(0xfff3f4f8)),
  PaperTemplate('frost', '磨砂', PaperMaterial.frost, Color(0xffe9edf0)),
  PaperTemplate(
      'blue_split', '雾蓝拼边', PaperMaterial.blueSplit, Color(0xffcad8e5)),
  PaperTemplate(
      'sage_edge', '鼠尾草双线', PaperMaterial.sageEdge, Color(0xffe3e9e1)),
  PaperTemplate(
      'rose_corner', '樱粉折角', PaperMaterial.roseCorner, Color(0xfff0e2e6)),
  PaperTemplate(
      'peel_white', '白色撕拉', PaperMaterial.peelWhite, Color(0xfff8f8f4)),
  PaperTemplate('peel_black', '黑色拉片', PaperMaterial.peelBlack,
      Color(0xff242526), Color(0xfff7f7f5)),
  PaperTemplate('clear', '透明描边', PaperMaterial.clear, Color(0xffe4ebef)),
  PaperTemplate('silver', '银箔', PaperMaterial.silver, Color(0xffcbd0d4)),
  PaperTemplate(
      'film', '胶片齿孔', PaperMaterial.film, Color(0xff24262b), Color(0xfff7f7f7)),
  PaperTemplate('letter', '信笺', PaperMaterial.letter, Color(0xfff7f7f6)),
  PaperTemplate('postmark', '旅行邮戳', PaperMaterial.postmark, Color(0xfff2f1ee)),
  PaperTemplate('archive', '双孔档案', PaperMaterial.archive, Color(0xffe6e8eb)),
  PaperTemplate('tape', '胶带留白', PaperMaterial.tape, Color(0xfffafafa)),
  PaperTemplate('wave', '波浪模切', PaperMaterial.wave, Color(0xffeceff5)),
  PaperTemplate('fold', '旧纸折痕', PaperMaterial.fold, Color(0xffefefeb)),
];

class TicketTemplate {
  final String id;
  final String label;
  final double aspectRatio;
  final int minimumPhotos;
  const TicketTemplate(this.id, this.label, this.aspectRatio,
      [this.minimumPhotos = 1]);
}

const ticketTemplates = [
  TicketTemplate('landscape', '横向纪念', 2.35),
  TicketTemplate('portrait', '竖向票根', .58),
  TicketTemplate('postcard', '城市明信片', 1.35),
  TicketTemplate('filmstrip', '胶片长票', .48, 2),
  TicketTemplate('couple', '双人拼图', 1.45, 2),
  TicketTemplate('datestamp', '日期纪念', .78),
  TicketTemplate('boarding', '旅途车票', 2.05),
  TicketTemplate('route', '路线纪念', .72),
];

class CreationLook {
  final String id;
  final String label;
  final String family;
  final double saturation;
  final double contrast;
  final double brightness;
  final double warmth;
  final double grain;
  final double vignette;
  final double softness;
  const CreationLook(this.id, this.label, this.family,
      {this.saturation = 1,
      this.contrast = 1,
      this.brightness = 0,
      this.warmth = 0,
      this.grain = 0,
      this.vignette = 0,
      this.softness = 0});

  List<double> matrix(double amount) {
    final s = saturation;
    final c = contrast;
    final offset = 128 * (1 - c) + brightness * 255;
    final tint = [1 + warmth * .12, 1.0, 1 - warmth * .12];
    const luma = [.2126, .7152, .0722];
    final result = List<double>.filled(20, 0);
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 3; column++) {
        final value =
            (luma[column] * (1 - s) + (row == column ? s : 0)) * c * tint[row];
        result[row * 5 + column] =
            (row == column ? 1 : 0) * (1 - amount) + value * amount;
      }
      result[row * 5 + 4] = offset * amount;
    }
    result[18] = 1;
    return result;
  }
}

const creationLooks = [
  CreationLook('instant_clear', '即时 01', '即时',
      saturation: .92,
      contrast: .94,
      brightness: .025,
      warmth: .12,
      vignette: .08),
  CreationLook('instant_soft', '即时 02', '即时',
      saturation: .76,
      contrast: .84,
      brightness: .05,
      warmth: .22,
      softness: .55,
      grain: .018),
  CreationLook('instant_flash', '即时 03', '即时',
      saturation: 1.08, contrast: 1.16, brightness: .045, vignette: .27),
  CreationLook('ccd_cool', 'CCD 01', 'CCD',
      saturation: .9, contrast: 1.12, warmth: -.5, grain: .025),
  CreationLook('ccd_pop', 'CCD 02', 'CCD',
      saturation: 1.28,
      contrast: 1.2,
      brightness: .01,
      warmth: -.16,
      vignette: .14),
  CreationLook('ccd_faded', 'CCD 03', 'CCD',
      saturation: .72, contrast: .8, brightness: .065, grain: .045),
  CreationLook('film_day', '胶片 01', '胶片',
      saturation: .9, contrast: 1.06, warmth: .1, grain: .025, vignette: .12),
  CreationLook('film_warm', '胶片 02', '胶片',
      saturation: .85, contrast: 1.08, warmth: .65, grain: .035, vignette: .18),
  CreationLook('film_grain', '胶片 03', '胶片',
      saturation: .8,
      contrast: 1.22,
      brightness: -.035,
      grain: .09,
      vignette: .3),
  CreationLook('bw_soft', '黑白 01', '黑白',
      saturation: 0, contrast: .86, brightness: .025, softness: .2),
  CreationLook('bw_contrast', '黑白 02', '黑白',
      saturation: 0, contrast: 1.5, brightness: -.035, vignette: .22),
  CreationLook('bw_grain', '黑白 03', '黑白',
      saturation: 0, contrast: 1.16, grain: .12, vignette: .3),
];
