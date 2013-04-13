/* pr29.h --- Detect strings that are non-idempotent under NFKC in Unicode 3.2.
   Copyright (C) 2004-2012 Simon Josefsson

   This file is part of GNU Libidn.

   GNU Libidn is free software: you can redistribute it and/or
   modify it under the terms of either:

     * the GNU Lesser General Public License as published by the Free
       Software Foundation; either version 3 of the License, or (at
       your option) any later version.

   or

     * the GNU General Public License as published by the Free
       Software Foundation; either version 2 of the License, or (at
       your option) any later version.

   or both in parallel, as here.

   GNU Libidn is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received copies of the GNU General Public License and
   the GNU Lesser General Public License along with this program.  If
   not, see <http://www.gnu.org/licenses/>. */

#include <config.h>

#include "pr29.h"

/* Get stringprep_utf8_to_ucs4. */
#include <stringprep.h>

/*
 * The tables used in this file was extracted by Simon Josefsson from
 * pr-29.html and DerivedCombiningClass-3.2.0.txt, as published by
 * Unicode Inc., for the GNU Libidn project.
 *
 */

/* These are the characters with non-zero combination class, extracted
   from DerivedCombiningClass-3.2.0.txt. */
static uint32_t nzcc[] = {
  /* 1 # Mn   [5] COMBINING TILDE OVERLAY..
   *                    ..COMBINING LONG SOLIDUS OVERLAY */
  0x0334,
  0x0335,
  0x0336,
  0x0337,
  0x0338,
  /* 1 # Mn   [2] COMBINING LONG VERTICAL LINE OVERLAY..
   *                    ..COMBINING SHORT VERTICAL LINE OVERLAY */
  0x20D2,
  0x20D3,
  /* 1 # Mn   [3] COMBINING RING OVERLAY..
   *                    ..COMBINING ANTICLOCKWISE RING OVERLAY */
  0x20D8,
  0x20D9,
  0x20DA,
  /* 1 # Mn   [2] COMBINING REVERSE SOLIDUS OVERLAY..
   *                    ..COMBINING DOUBLE VERTICAL STROKE OVERLAY */
  0x20E5,
  0x20E6,
  /* 1 # Mn       COMBINING LEFTWARDS ARROW OVERLAY */
  0x20EA,
  /* 1 # Mn   [3] MUSICAL SYMBOL COMBINING TREMOLO-1..
   *                    ..MUSICAL SYMBOL COMBINING TREMOLO-3 */
  0x1D167,
  0x1D168,
  0x1D169,
  /* 7 # Mn       DEVANAGARI SIGN NUKTA */
  0x093C,
  /* 7 # Mn       BENGALI SIGN NUKTA */
  0x09BC,
  /* 7 # Mn       GURMUKHI SIGN NUKTA */
  0x0A3C,
  /* 7 # Mn       GUJARATI SIGN NUKTA */
  0x0ABC,
  /* 7 # Mn       ORIYA SIGN NUKTA */
  0x0B3C,
  /* 7 # Mn       MYANMAR SIGN DOT BELOW */
  0x1037,
  /* 8 # Mn   [2] COMBINING KATAKANA-HIRAGANA VOICED SOUND MARK..
   *                    ..COMBINING KATAKANA-HIRAGANA SEMI-VOICED SOUND MARK */
  0x3099,
  0x309A,
  /* 9 # Mn       DEVANAGARI SIGN VIRAMA */
  0x094D,
  /* 9 # Mn       BENGALI SIGN VIRAMA */
  0x09CD,
  /* 9 # Mn       GURMUKHI SIGN VIRAMA */
  0x0A4D,
  /* 9 # Mn       GUJARATI SIGN VIRAMA */
  0x0ACD,
  /* 9 # Mn       ORIYA SIGN VIRAMA */
  0x0B4D,
  /* 9 # Mn       TAMIL SIGN VIRAMA */
  0x0BCD,
  /* 9 # Mn       TELUGU SIGN VIRAMA */
  0x0C4D,
  /* 9 # Mn       KANNADA SIGN VIRAMA */
  0x0CCD,
  /* 9 # Mn       MALAYALAM SIGN VIRAMA */
  0x0D4D,
  /* 9 # Mn       SINHALA SIGN AL-LAKUNA */
  0x0DCA,
  /* 9 # Mn       THAI CHARACTER PHINTHU */
  0x0E3A,
  /* 9 # Mn       TIBETAN MARK HALANTA */
  0x0F84,
  /* 9 # Mn       MYANMAR SIGN VIRAMA */
  0x1039,
  /* 9 # Mn       TAGALOG SIGN VIRAMA */
  0x1714,
  /* 9 # Mn       HANUNOO SIGN PAMUDPOD */
  0x1734,
  /* 9 # Mn       KHMER SIGN COENG */
  0x17D2,
  /* 10 # Mn       HEBREW POINT SHEVA */
  0x05B0,
  /* 11 # Mn       HEBREW POINT HATAF SEGOL */
  0x05B1,
  /* 12 # Mn       HEBREW POINT HATAF PATAH */
  0x05B2,
  /* 13 # Mn       HEBREW POINT HATAF QAMATS */
  0x05B3,
  /* 14 # Mn       HEBREW POINT HIRIQ */
  0x05B4,
  /* 15 # Mn       HEBREW POINT TSERE */
  0x05B5,
  /* 16 # Mn       HEBREW POINT SEGOL */
  0x05B6,
  /* 17 # Mn       HEBREW POINT PATAH */
  0x05B7,
  /* 18 # Mn       HEBREW POINT QAMATS */
  0x05B8,
  /* 19 # Mn       HEBREW POINT HOLAM */
  0x05B9,
  /* 20 # Mn       HEBREW POINT QUBUTS */
  0x05BB,
  /* 21 # Mn       HEBREW POINT DAGESH OR MAPIQ */
  0x05BC,
  /* 22 # Mn       HEBREW POINT METEG */
  0x05BD,
  /* 23 # Mn       HEBREW POINT RAFE */
  0x05BF,
  /* 24 # Mn       HEBREW POINT SHIN DOT */
  0x05C1,
  /* 25 # Mn       HEBREW POINT SIN DOT */
  0x05C2,
  /* 26 # Mn       HEBREW POINT JUDEO-SPANISH VARIKA */
  0xFB1E,
  /* 27 # Mn       ARABIC FATHATAN */
  0x064B,
  /* 28 # Mn       ARABIC DAMMATAN */
  0x064C,
  /* 29 # Mn       ARABIC KASRATAN */
  0x064D,
  /* 30 # Mn       ARABIC FATHA */
  0x064E,
  /* 31 # Mn       ARABIC DAMMA */
  0x064F,
  /* 32 # Mn       ARABIC KASRA */
  0x0650,
  /* 33 # Mn       ARABIC SHADDA */
  0x0651,
  /* 34 # Mn       ARABIC SUKUN */
  0x0652,
  /* 35 # Mn       ARABIC LETTER SUPERSCRIPT ALEF */
  0x0670,
  /* 36 # Mn       SYRIAC LETTER SUPERSCRIPT ALAPH */
  0x0711,
  /* 84 # Mn       TELUGU LENGTH MARK */
  0x0C55,
  /* 91 # Mn       TELUGU AI LENGTH MARK */
  0x0C56,
  /* 103 # Mn   [2] THAI CHARACTER SARA U..
   *                    ..THAI CHARACTER SARA UU */
  0x0E38,
  0x0E39,
  /* 107 # Mn   [4] THAI CHARACTER MAI EK..
   *                    ..THAI CHARACTER MAI CHATTAWA */
  0x0E48,
  0x0E49,
  0x0E4A,
  0x04EB,
  /* 118 # Mn   [2] LAO VOWEL SIGN U..
   *                    ..LAO VOWEL SIGN UU */
  0x0EB8,
  0x0EB9,
  /* 122 # Mn   [4] LAO TONE MAI EK..
   *                    ..LAO TONE MAI CATAWA */
  0x0EC8,
  0x0EC9,
  0x0ECA,
  0x0ECB,
  /* 129 # Mn       TIBETAN VOWEL SIGN AA */
  0x0F71,
  /* 130 # Mn       TIBETAN VOWEL SIGN I */
  0x0F72,
  /* 130 # Mn   [4] TIBETAN VOWEL SIGN E..
   *                    ..TIBETAN VOWEL SIGN OO */
  0x0F7A,
  0x0F7B,
  0x0F7C,
  0x0F7D,
  /* 130 # Mn       TIBETAN VOWEL SIGN REVERSED I */
  0x0F80,
  /* 132 # Mn       TIBETAN VOWEL SIGN U */
  0x0F74,
  /* 202 # Mn   [2] COMBINING PALATALIZED HOOK BELOW..
   *                    ..COMBINING RETROFLEX HOOK BELOW */
  0x0321,
  0x0322,
  /* 202 # Mn   [2] COMBINING CEDILLA..
   *                    ..COMBINING OGONEK */
  0x0327,
  0x0328,
  /* 216 # Mn       COMBINING HORN */
  0x031B,
  /* 216 # Mn       TIBETAN MARK TSA -PHRU */
  0x0F39,
  /* 216 # Mc   [2] MUSICAL SYMBOL COMBINING STEM..
   *                    ..MUSICAL SYMBOL COMBINING SPRECHGESANG STEM */
  0x1D165,
  0x1D166,
  /* 216 # Mc   [5] MUSICAL SYMBOL COMBINING FLAG-1..
   *                    ..MUSICAL SYMBOL COMBINING FLAG-5 */
  0x1D16E,
  0x1D16F,
  0x1D170,
  0x1D171,
  0x1D172,
  /* 218 # Mn       IDEOGRAPHIC LEVEL TONE MARK */
  0x302A,
  /* 220 # Mn   [4] COMBINING GRAVE ACCENT BELOW..
   *                    ..COMBINING RIGHT TACK BELOW */
  0x0316,
  0x0317,
  0x0318,
  0x0319,
  /* 220 # Mn   [5] COMBINING LEFT HALF RING BELOW..
   *                    ..COMBINING MINUS SIGN BELOW */
  0x031C,
  0x031D,
  0x031E,
  0x031F,
  0x0320,
  /* 220 # Mn   [4] COMBINING DOT BELOW..
   *                    ..COMBINING COMMA BELOW */
  0x0323,
  0x0324,
  0x0325,
  0x0326,
  /* 220 # Mn  [11] COMBINING VERTICAL LINE BELOW..
   *                    ..COMBINING DOUBLE LOW LINE */
  0x0329,
  0x032A,
  0x032B,
  0x032C,
  0x032D,
  0x032E,
  0x032F,
  0x0330,
  0x0331,
  0x0332,
  0x0333,
  /* 220 # Mn   [4] COMBINING RIGHT HALF RING BELOW..
   *                    ..COMBINING SEAGULL BELOW */
  0x0339,
  0x033A,
  0x033B,
  0x033C,
  /* 220 # Mn   [3] COMBINING EQUALS SIGN BELOW..
   *                    ..COMBINING LEFT ANGLE BELOW */
  0x0347,
  0x0348,
  0x0349,
  /* 220 # Mn   [2] COMBINING LEFT RIGHT ARROW BELOW..
   *                    ..COMBINING UPWARDS ARROW BELOW */
  0x034D,
  0x034E,
  /* 220 # Mn       HEBREW ACCENT ETNAHTA */
  0x0591,
  /* 220 # Mn       HEBREW ACCENT TIPEHA */
  0x0596,
  /* 220 # Mn       HEBREW ACCENT TEVIR */
  0x059B,
  /* 220 # Mn   [5] HEBREW ACCENT MUNAH..
   *                    ..HEBREW ACCENT DARGA */
  0x05A3,
  0x05A4,
  0x05A5,
  0x05A6,
  0x05A7,
  /* 220 # Mn       HEBREW ACCENT YERAH BEN YOMO */
  0x05AA,
  /* 220 # Mn       ARABIC HAMZA BELOW */
  0x0655,
  /* 220 # Mn       ARABIC SMALL LOW SEEN */
  0x06E3,
  /* 220 # Mn       ARABIC EMPTY CENTRE LOW STOP */
  0x06EA,
  /* 220 # Mn       ARABIC SMALL LOW MEEM */
  0x06ED,
  /* 220 # Mn       SYRIAC PTHAHA BELOW */
  0x0731,
  /* 220 # Mn       SYRIAC ZQAPHA BELOW */
  0x0734,
  /* 220 # Mn   [3] SYRIAC RBASA BELOW..
   *                    ..SYRIAC DOTTED ZLAMA ANGULAR */
  0x0737,
  0x0738,
  0x0739,
  /* 220 # Mn   [2] SYRIAC HBASA BELOW..
   *                    ..SYRIAC HBASA-ESASA DOTTED */
  0x073B,
  0x073C,
  /* 220 # Mn       SYRIAC ESASA BELOW */
  0x073E,
  /* 220 # Mn       SYRIAC RUKKAKHA */
  0x0742,
  /* 220 # Mn       SYRIAC TWO VERTICAL DOTS BELOW */
  0x0744,
  /* 220 # Mn       SYRIAC THREE DOTS BELOW */
  0x0746,
  /* 220 # Mn       SYRIAC OBLIQUE LINE BELOW */
  0x0748,
  /* 220 # Mn       DEVANAGARI STRESS SIGN ANUDATTA */
  0x0952,
  /* 220 # Mn   [2] TIBETAN ASTROLOGICAL SIGN -KHYUD PA..
   *                    ..TIBETAN ASTROLOGICAL SIGN SDONG TSHUGS */
  0x0F18,
  0x0F19,
  /* 220 # Mn       TIBETAN MARK NGAS BZUNG NYI ZLA */
  0x0F35,
  /* 220 # Mn       TIBETAN MARK NGAS BZUNG SGOR RTAGS */
  0x0F37,
  /* 220 # Mn       TIBETAN SYMBOL PADMA GDAN */
  0x0FC6,
  /* 220 # Mn       COMBINING TRIPLE UNDERDOT */
  0x20E8,
  /* 220 # Mn   [8] MUSICAL SYMBOL COMBINING ACCENT..
   *                    ..MUSICAL SYMBOL COMBINING LOURE */
  0x1D17B,
  0x1D17C,
  0x1D17D,
  0x1D17E,
  0x1D17F,
  0x1D180,
  0x1D181,
  0x1D182,
  /* 220 # Mn   [2] MUSICAL SYMBOL COMBINING DOUBLE TONGUE..
   *                    ..MUSICAL SYMBOL COMBINING TRIPLE TONGUE */
  0x1D18A,
  0x1D18B,
  /* 222 # Mn       HEBREW ACCENT YETIV */
  0x059A,
  /* 222 # Mn       HEBREW ACCENT DEHI */
  0x05AD,
  /* 222 # Mn       IDEOGRAPHIC ENTERING TONE MARK */
  0x302D,
  /* 224 # Mn   [2] HANGUL SINGLE DOT TONE MARK..
   *                    ..HANGUL DOUBLE DOT TONE MARK */
  0x302E,
  0x302F,
  /* 226 # Mc       MUSICAL SYMBOL COMBINING AUGMENTATION DOT */
  0x1D16D,
  /* 228 # Mn       HEBREW ACCENT ZINOR */
  0x05AE,
  /* 228 # Mn       MONGOLIAN LETTER ALI GALI DAGALGA */
  0x18A9,
  /* 228 # Mn       IDEOGRAPHIC RISING TONE MARK */
  0x302B,
  /* 230 # Mn  [21] COMBINING GRAVE ACCENT..
   *                    ..COMBINING REVERSED COMMA ABOVE */
  0x0300,
  0x0301,
  0x0302,
  0x0303,
  0x0304,
  0x0305,
  0x0306,
  0x0307,
  0x0308,
  0x0309,
  0x030A,
  0x030B,
  0x030C,
  0x030D,
  0x030E,
  0x030F,
  0x0310,
  0x0311,
  0x0312,
  0x0313,
  0x0314,
  /* 230 # Mn   [8] COMBINING X ABOVE..
   *                    ..COMBINING GREEK DIALYTIKA TONOS */
  0x033D,
  0x033E,
  0x033F,
  0x0340,
  0x0341,
  0x0342,
  0x0343,
  0x0344,
  /* 230 # Mn       COMBINING BRIDGE ABOVE */
  0x0346,
  /* 230 # Mn   [3] COMBINING NOT TILDE ABOVE..
   *                    ..COMBINING ALMOST EQUAL TO ABOVE */
  0x034A,
  0x034B,
  0x034C,
  /* 230 # Mn  [13] COMBINING LATIN SMALL LETTER A..
   *                    ..COMBINING LATIN SMALL LETTER X */
  0x0363,
  0x0364,
  0x0365,
  0x0366,
  0x0367,
  0x0368,
  0x0369,
  0x036A,
  0x036B,
  0x036C,
  0x036D,
  0x036E,
  0x036F,
  /* 230 # Mn   [4] COMBINING CYRILLIC TITLO..
   *                    ..COMBINING CYRILLIC PSILI PNEUMATA */
  0x0483,
  0x0484,
  0x0485,
  0x0486,
  /* 230 # Mn   [4] HEBREW ACCENT SEGOL..
   *                    ..HEBREW ACCENT ZAQEF GADOL */
  0x0592,
  0x0593,
  0x0594,
  0x0595,
  /* 230 # Mn   [3] HEBREW ACCENT REVIA..
   *                    ..HEBREW ACCENT PASHTA */
  0x0597,
  0x0598,
  0x0599,
  /* 230 # Mn   [6] HEBREW ACCENT GERESH..
   *                    ..HEBREW ACCENT PAZER */
  0x059C,
  0x059D,
  0x059E,
  0x059F,
  0x05A0,
  0x05A1,
  /* 230 # Mn   [2] HEBREW ACCENT QADMA..
   *                    ..HEBREW ACCENT TELISHA QETANA */
  0x05A8,
  0x05A9,
  /* 230 # Mn   [2] HEBREW ACCENT OLE..
   *                    ..HEBREW ACCENT ILUY */
  0x05AB,
  0x05AC,
  /* 230 # Mn       HEBREW MARK MASORA CIRCLE */
  0x05AF,
  /* 230 # Mn       HEBREW MARK UPPER DOT */
  0x05C4,
  /* 230 # Mn   [2] ARABIC MADDAH ABOVE..
   *                    ..ARABIC HAMZA ABOVE */
  0x0653,
  0x0654,
  /* 230 # Mn   [7] ARABIC SMALL HIGH LIGATURE SAD WITH LAM WITH ALEF MAKSURA..
   *                    ..ARABIC SMALL HIGH SEEN */
  0x06D6,
  0x06D7,
  0x06D8,
  0x06D9,
  0x06DA,
  0x06DB,
  0x06DC,
  /* 230 # Mn   [4] ARABIC SMALL HIGH ROUNDED ZERO..
   *                    ..ARABIC SMALL HIGH MEEM ISOLATED FORM */
  0x06DF,
  0x06E0,
  0x06E1,
  0x06E2,
  /* 230 # Mn       ARABIC SMALL HIGH MADDA */
  0x06E4,
  /* 230 # Mn   [2] ARABIC SMALL HIGH YEH..
   *                    ..ARABIC SMALL HIGH NOON */
  0x06E7,
  0x06E8,
  /* 230 # Mn   [2] ARABIC EMPTY CENTRE HIGH STOP..
   *                    ..ARABIC ROUNDED HIGH STOP WITH FILLED CENTRE */
  0x06EB,
  0x06EC,
  /* 230 # Mn       SYRIAC PTHAHA ABOVE */
  0x0730,
  /* 230 # Mn   [2] SYRIAC PTHAHA DOTTED..
   *                    ..SYRIAC ZQAPHA ABOVE */
  0x0732,
  0x0733,
  /* 230 # Mn   [2] SYRIAC ZQAPHA DOTTED..
   *                    ..SYRIAC RBASA ABOVE */
  0x0735,
  0x0736,
  /* 230 # Mn       SYRIAC HBASA ABOVE */
  0x073A,
  /* 230 # Mn       SYRIAC ESASA ABOVE */
  0x073D,
  /* 230 # Mn   [3] SYRIAC RWAHA..
   *                    ..SYRIAC QUSHSHAYA */
  0x073F,
  0x0740,
  0x0741,
  /* 230 # Mn       SYRIAC TWO VERTICAL DOTS ABOVE */
  0x0743,
  /* 230 # Mn       SYRIAC THREE DOTS ABOVE */
  0x0745,
  /* 230 # Mn       SYRIAC OBLIQUE LINE ABOVE */
  0x0747,
  /* 230 # Mn   [2] SYRIAC MUSIC..
   *                    ..SYRIAC BARREKH */
  0x0749,
  0x074A,
  /* 230 # Mn       DEVANAGARI STRESS SIGN UDATTA */
  0x0951,
  /* 230 # Mn   [2] DEVANAGARI GRAVE ACCENT..
   *                    ..DEVANAGARI ACUTE ACCENT */
  0x0953,
  0x0954,
  /* 230 # Mn   [2] TIBETAN SIGN NYI ZLA NAA DA..
   *                    ..TIBETAN SIGN SNA LDAN */
  0x0F82,
  0x0F83,
  /* 230 # Mn   [2] TIBETAN SIGN LCI RTAGS..
   *                    ..TIBETAN SIGN YANG RTAGS */
  0x0F86,
  0x0F87,
  /* 230 # Mn   [2] COMBINING LEFT HARPOON ABOVE..
   *                    ..COMBINING RIGHT HARPOON ABOVE */
  0x20D0,
  0x20D1,
  /* 230 # Mn   [4] COMBINING ANTICLOCKWISE ARROW ABOVE..
   *                    ..COMBINING RIGHT ARROW ABOVE */
  0x20D4,
  0x20D5,
  0x20D6,
  0x20D7,
  /* 230 # Mn   [2] COMBINING THREE DOTS ABOVE..
   *                    ..COMBINING FOUR DOTS ABOVE */
  0x20DB,
  0x20DC,
  /* 230 # Mn       COMBINING LEFT RIGHT ARROW ABOVE */
  0x20E1,
  /* 230 # Mn       COMBINING ANNUITY SYMBOL */
  0x20E7,
  /* 230 # Mn       COMBINING WIDE BRIDGE ABOVE */
  0x20E9,
  /* 230 # Mn   [4] COMBINING LIGATURE LEFT HALF..
   *                    ..COMBINING DOUBLE TILDE RIGHT HALF */
  0xFE20,
  0xFE21,
  0xFE22,
  0xFE23,
  /* 230 # Mn   [5] MUSICAL SYMBOL COMBINING DOIT..
   *                    ..MUSICAL SYMBOL COMBINING BEND */
  0x1D185,
  0x1D186,
  0x1D187,
  0x1D188,
  0x1D189,
  /* 230 # Mn   [4] MUSICAL SYMBOL COMBINING DOWN BOW..
   *                    ..MUSICAL SYMBOL COMBINING SNAP PIZZICATO */
  0x1D1AA,
  0x1D1AB,
  0x1D1AC,
  0x1D1AD,
  /* 232 # Mn       COMBINING COMMA ABOVE RIGHT */
  0x0315,
  /* 232 # Mn       COMBINING LEFT ANGLE ABOVE */
  0x031A,
  /* 232 # Mn       IDEOGRAPHIC DEPARTING TONE MARK */
  0x302C,
  /* 233 # Mn       COMBINING DOUBLE RIGHTWARDS ARROW BELOW */
  0x0362,
  /* 234 # Mn   [2] COMBINING DOUBLE TILDE..
   *                    ..COMBINING DOUBLE INVERTED BREVE */
  0x0360,
  0x0361,
  /* 240 # Mn       COMBINING GREEK YPOGEGRAMMENI */
  0x0345,
  0
};

/*
 * 09C7 BENGALI VOWEL SIGN E    09BE BENGALI VOWEL SIGN AA or
 *                              09D7 BENGALI AU LENGTH MARK
 */

static const uint32_t pr29_1_1[] = {
  0x09C7, 0
};

static const uint32_t pr29_1_2[] = {
  0x09BE, 0x09D7, 0
};

/*
 * 0B47 ORIYA VOWEL SIGN E      0B3E ORIYA VOWEL SIGN AA or
 *                              0B56 ORIYA AI LENGTH MARK or
 *                              0B57 ORIYA AU LENGTH MARK
 */

static const uint32_t pr29_2_1[] = {
  0x0B47, 0
};

static const uint32_t pr29_2_2[] = {
  0x0B3E, 0x0B56, 0x0B57, 0
};

/*
 * 0BC6 TAMIL VOWEL SIGN E      0BBE TAMIL VOWEL SIGN AA or
 *                              0BD7 TAMIL AU LENGTH MARK
 */

static const uint32_t pr29_3_1[] = {
  0x0BC6, 0
};

static const uint32_t pr29_3_2[] = {
  0x0BBE, 0x0BD7, 0
};

/*
 * 0BC7 TAMIL VOWEL SIGN EE     0BBE TAMIL VOWEL SIGN AA
 */

static const uint32_t pr29_4_1[] = {
  0x0BC7, 0
};

static const uint32_t pr29_4_2[] = {
  0x0BBE, 0
};

/*
 * 0B92 TAMIL LETTER O          0BD7 TAMIL AU LENGTH MARK
 */

static const uint32_t pr29_5_1[] = {
  0x0B92, 0
};

static const uint32_t pr29_5_2[] = {
  0x0BD7, 0
};

/*
 * 0CC6 KANNADA VOWEL SIGN E    0CC2 KANNADA VOWEL SIGN UU or
 *                              0CD5 KANNADA LENGTH MARK or
 *                              0CD6 KANNADA AI LENGTH MARK
 */

static const uint32_t pr29_6_1[] = {
  0x0CC6, 0
};

static const uint32_t pr29_6_2[] = {
  0x0CC2, 0xCD5, 0xCD6, 0
};

/*
 * 0CBF KANNADA VOWEL SIGN I or
 * 0CCA KANNADA VOWEL SIGN O    0CD5 KANNADA LENGTH MARK
 */

static const uint32_t pr29_7_1[] = {
  0x0CBF, 0xCCA, 0
};

static const uint32_t pr29_7_2[] = {
  0x0CD5, 0
};

/*
 * 0D47 MALAYALAM VOWEL SIGN EE         0D3E MALAYALAM VOWEL SIGN AA
 */

static const uint32_t pr29_8_1[] = {
  0x0D47, 0
};

static const uint32_t pr29_8_2[] = {
  0x0D3E, 0
};

/*
 * 0D46 MALAYALAM VOWEL SIGN E          0D3E MALAYALAM VOWEL SIGN AA or
 *                                      0D57 MALAYALAM AU LENGTH MARK
 */

static const uint32_t pr29_9_1[] = {
  0x0D46, 0
};

static const uint32_t pr29_9_2[] = {
  0x0D3E, 0x0D57, 0
};

/*
 * 1025 MYANMAR LETTER U                102E MYANMAR VOWEL SIGN II
 */

static const uint32_t pr29_10_1[] = {
  0x1025, 0
};

static const uint32_t pr29_10_2[] = {
  0x102E, 0
};

/*
 * 0DD9 SINHALA VOWEL SIGN KOMBUVA      0DCF SINHALA VOWEL SIGN AELA-PILLA or
 *                                      0DDF SINHALA VOWEL SIGN GAYANUKITTA
 */

static const uint32_t pr29_11_1[] = {
  0x0DD9, 0
};

static const uint32_t pr29_11_2[] = {
  0x0DCF, 0x0DDF, 0
};

/*
 * 1100..1112 HANGUL CHOSEONG KIYEOK..HIEUH [19 instances]
 *                              1161..1175 HANGUL JUNGSEONG A..I [21 instances]
 */

static const uint32_t pr29_12_1[] = {
  0x1100, 0x1101, 0x1102, 0x1103, 0x1104, 0x1105, 0x1106, 0x1107,
  0x1108, 0x1109, 0x110A, 0x110B, 0x110C, 0x110D, 0x110E, 0x110F,
  0x1110, 0x1111, 0x1112, 0
};

static const uint32_t pr29_12_2[] = {
  0x1161, 0x1162, 0x1163, 0x1164, 0x1165, 0x1166, 0x1167, 0x1168,
  0x1169, 0x116A, 0x116B, 0x116C, 0x116D, 0x116E, 0x116F, 0x1170,
  0x1171, 0x1172, 0x1173, 0x1174, 0x1175, 0
};


/*
 * [:HangulSyllableType=LV:]
 *                     11A8..11C2 HANGUL JONGSEONG KIYEOK..HIEUH [27 instances]
 */

static const uint32_t pr29_13_1[] = {
  0xAC00,			/* LV # Lo       HANGUL SYLLABLE GA     */
  0xAC1C,			/* LV # Lo       HANGUL SYLLABLE GAE    */
  0xAC38,			/* LV # Lo       HANGUL SYLLABLE GYA    */
  0xAC54,			/* LV # Lo       HANGUL SYLLABLE GYAE   */
  0xAC70,			/* LV # Lo       HANGUL SYLLABLE GEO    */
  0xAC8C,			/* LV # Lo       HANGUL SYLLABLE GE     */
  0xACA8,			/* LV # Lo       HANGUL SYLLABLE GYEO   */
  0xACC4,			/* LV # Lo       HANGUL SYLLABLE GYE    */
  0xACE0,			/* LV # Lo       HANGUL SYLLABLE GO     */
  0xACFC,			/* LV # Lo       HANGUL SYLLABLE GWA    */
  0xAD18,			/* LV # Lo       HANGUL SYLLABLE GWAE   */
  0xAD34,			/* LV # Lo       HANGUL SYLLABLE GOE    */
  0xAD50,			/* LV # Lo       HANGUL SYLLABLE GYO    */
  0xAD6C,			/* LV # Lo       HANGUL SYLLABLE GU     */
  0xAD88,			/* LV # Lo       HANGUL SYLLABLE GWEO   */
  0xADA4,			/* LV # Lo       HANGUL SYLLABLE GWE    */
  0xADC0,			/* LV # Lo       HANGUL SYLLABLE GWI    */
  0xADDC,			/* LV # Lo       HANGUL SYLLABLE GYU    */
  0xADF8,			/* LV # Lo       HANGUL SYLLABLE GEU    */
  0xAE14,			/* LV # Lo       HANGUL SYLLABLE GYI    */
  0xAE30,			/* LV # Lo       HANGUL SYLLABLE GI     */
  0xAE4C,			/* LV # Lo       HANGUL SYLLABLE GGA    */
  0xAE68,			/* LV # Lo       HANGUL SYLLABLE GGAE   */
  0xAE84,			/* LV # Lo       HANGUL SYLLABLE GGYA   */
  0xAEA0,			/* LV # Lo       HANGUL SYLLABLE GGYAE  */
  0xAEBC,			/* LV # Lo       HANGUL SYLLABLE GGEO   */
  0xAED8,			/* LV # Lo       HANGUL SYLLABLE GGE    */
  0xAEF4,			/* LV # Lo       HANGUL SYLLABLE GGYEO  */
  0xAF10,			/* LV # Lo       HANGUL SYLLABLE GGYE   */
  0xAF2C,			/* LV # Lo       HANGUL SYLLABLE GGO    */
  0xAF48,			/* LV # Lo       HANGUL SYLLABLE GGWA   */
  0xAF64,			/* LV # Lo       HANGUL SYLLABLE GGWAE  */
  0xAF80,			/* LV # Lo       HANGUL SYLLABLE GGOE   */
  0xAF9C,			/* LV # Lo       HANGUL SYLLABLE GGYO   */
  0xAFB8,			/* LV # Lo       HANGUL SYLLABLE GGU    */
  0xAFD4,			/* LV # Lo       HANGUL SYLLABLE GGWEO  */
  0xAFF0,			/* LV # Lo       HANGUL SYLLABLE GGWE   */
  0xB00C,			/* LV # Lo       HANGUL SYLLABLE GGWI   */
  0xB028,			/* LV # Lo       HANGUL SYLLABLE GGYU   */
  0xB044,			/* LV # Lo       HANGUL SYLLABLE GGEU   */
  0xB060,			/* LV # Lo       HANGUL SYLLABLE GGYI   */
  0xB07C,			/* LV # Lo       HANGUL SYLLABLE GGI    */
  0xB098,			/* LV # Lo       HANGUL SYLLABLE NA     */
  0xB0B4,			/* LV # Lo       HANGUL SYLLABLE NAE    */
  0xB0D0,			/* LV # Lo       HANGUL SYLLABLE NYA    */
  0xB0EC,			/* LV # Lo       HANGUL SYLLABLE NYAE   */
  0xB108,			/* LV # Lo       HANGUL SYLLABLE NEO    */
  0xB124,			/* LV # Lo       HANGUL SYLLABLE NE     */
  0xB140,			/* LV # Lo       HANGUL SYLLABLE NYEO   */
  0xB15C,			/* LV # Lo       HANGUL SYLLABLE NYE    */
  0xB178,			/* LV # Lo       HANGUL SYLLABLE NO     */
  0xB194,			/* LV # Lo       HANGUL SYLLABLE NWA    */
  0xB1B0,			/* LV # Lo       HANGUL SYLLABLE NWAE   */
  0xB1CC,			/* LV # Lo       HANGUL SYLLABLE NOE    */
  0xB1E8,			/* LV # Lo       HANGUL SYLLABLE NYO    */
  0xB204,			/* LV # Lo       HANGUL SYLLABLE NU     */
  0xB220,			/* LV # Lo       HANGUL SYLLABLE NWEO   */
  0xB23C,			/* LV # Lo       HANGUL SYLLABLE NWE    */
  0xB258,			/* LV # Lo       HANGUL SYLLABLE NWI    */
  0xB274,			/* LV # Lo       HANGUL SYLLABLE NYU    */
  0xB290,			/* LV # Lo       HANGUL SYLLABLE NEU    */
  0xB2AC,			/* LV # Lo       HANGUL SYLLABLE NYI    */
  0xB2C8,			/* LV # Lo       HANGUL SYLLABLE NI     */
  0xB2E4,			/* LV # Lo       HANGUL SYLLABLE DA     */
  0xB300,			/* LV # Lo       HANGUL SYLLABLE DAE    */
  0xB31C,			/* LV # Lo       HANGUL SYLLABLE DYA    */
  0xB338,			/* LV # Lo       HANGUL SYLLABLE DYAE   */
  0xB354,			/* LV # Lo       HANGUL SYLLABLE DEO    */
  0xB370,			/* LV # Lo       HANGUL SYLLABLE DE     */
  0xB38C,			/* LV # Lo       HANGUL SYLLABLE DYEO   */
  0xB3A8,			/* LV # Lo       HANGUL SYLLABLE DYE    */
  0xB3C4,			/* LV # Lo       HANGUL SYLLABLE DO     */
  0xB3E0,			/* LV # Lo       HANGUL SYLLABLE DWA    */
  0xB3FC,			/* LV # Lo       HANGUL SYLLABLE DWAE   */
  0xB418,			/* LV # Lo       HANGUL SYLLABLE DOE    */
  0xB434,			/* LV # Lo       HANGUL SYLLABLE DYO    */
  0xB450,			/* LV # Lo       HANGUL SYLLABLE DU     */
  0xB46C,			/* LV # Lo       HANGUL SYLLABLE DWEO   */
  0xB488,			/* LV # Lo       HANGUL SYLLABLE DWE    */
  0xB4A4,			/* LV # Lo       HANGUL SYLLABLE DWI    */
  0xB4C0,			/* LV # Lo       HANGUL SYLLABLE DYU    */
  0xB4DC,			/* LV # Lo       HANGUL SYLLABLE DEU    */
  0xB4F8,			/* LV # Lo       HANGUL SYLLABLE DYI    */
  0xB514,			/* LV # Lo       HANGUL SYLLABLE DI     */
  0xB530,			/* LV # Lo       HANGUL SYLLABLE DDA    */
  0xB54C,			/* LV # Lo       HANGUL SYLLABLE DDAE   */
  0xB568,			/* LV # Lo       HANGUL SYLLABLE DDYA   */
  0xB584,			/* LV # Lo       HANGUL SYLLABLE DDYAE  */
  0xB5A0,			/* LV # Lo       HANGUL SYLLABLE DDEO   */
  0xB5BC,			/* LV # Lo       HANGUL SYLLABLE DDE    */
  0xB5D8,			/* LV # Lo       HANGUL SYLLABLE DDYEO  */
  0xB5F4,			/* LV # Lo       HANGUL SYLLABLE DDYE   */
  0xB610,			/* LV # Lo       HANGUL SYLLABLE DDO    */
  0xB62C,			/* LV # Lo       HANGUL SYLLABLE DDWA   */
  0xB648,			/* LV # Lo       HANGUL SYLLABLE DDWAE  */
  0xB664,			/* LV # Lo       HANGUL SYLLABLE DDOE   */
  0xB680,			/* LV # Lo       HANGUL SYLLABLE DDYO   */
  0xB69C,			/* LV # Lo       HANGUL SYLLABLE DDU    */
  0xB6B8,			/* LV # Lo       HANGUL SYLLABLE DDWEO  */
  0xB6D4,			/* LV # Lo       HANGUL SYLLABLE DDWE   */
  0xB6F0,			/* LV # Lo       HANGUL SYLLABLE DDWI   */
  0xB70C,			/* LV # Lo       HANGUL SYLLABLE DDYU   */
  0xB728,			/* LV # Lo       HANGUL SYLLABLE DDEU   */
  0xB744,			/* LV # Lo       HANGUL SYLLABLE DDYI   */
  0xB760,			/* LV # Lo       HANGUL SYLLABLE DDI    */
  0xB77C,			/* LV # Lo       HANGUL SYLLABLE RA     */
  0xB798,			/* LV # Lo       HANGUL SYLLABLE RAE    */
  0xB7B4,			/* LV # Lo       HANGUL SYLLABLE RYA    */
  0xB7D0,			/* LV # Lo       HANGUL SYLLABLE RYAE   */
  0xB7EC,			/* LV # Lo       HANGUL SYLLABLE REO    */
  0xB808,			/* LV # Lo       HANGUL SYLLABLE RE     */
  0xB824,			/* LV # Lo       HANGUL SYLLABLE RYEO   */
  0xB840,			/* LV # Lo       HANGUL SYLLABLE RYE    */
  0xB85C,			/* LV # Lo       HANGUL SYLLABLE RO     */
  0xB878,			/* LV # Lo       HANGUL SYLLABLE RWA    */
  0xB894,			/* LV # Lo       HANGUL SYLLABLE RWAE   */
  0xB8B0,			/* LV # Lo       HANGUL SYLLABLE ROE    */
  0xB8CC,			/* LV # Lo       HANGUL SYLLABLE RYO    */
  0xB8E8,			/* LV # Lo       HANGUL SYLLABLE RU     */
  0xB904,			/* LV # Lo       HANGUL SYLLABLE RWEO   */
  0xB920,			/* LV # Lo       HANGUL SYLLABLE RWE    */
  0xB93C,			/* LV # Lo       HANGUL SYLLABLE RWI    */
  0xB958,			/* LV # Lo       HANGUL SYLLABLE RYU    */
  0xB974,			/* LV # Lo       HANGUL SYLLABLE REU    */
  0xB990,			/* LV # Lo       HANGUL SYLLABLE RYI    */
  0xB9AC,			/* LV # Lo       HANGUL SYLLABLE RI     */
  0xB9C8,			/* LV # Lo       HANGUL SYLLABLE MA     */
  0xB9E4,			/* LV # Lo       HANGUL SYLLABLE MAE    */
  0xBA00,			/* LV # Lo       HANGUL SYLLABLE MYA    */
  0xBA1C,			/* LV # Lo       HANGUL SYLLABLE MYAE   */
  0xBA38,			/* LV # Lo       HANGUL SYLLABLE MEO    */
  0xBA54,			/* LV # Lo       HANGUL SYLLABLE ME     */
  0xBA70,			/* LV # Lo       HANGUL SYLLABLE MYEO   */
  0xBA8C,			/* LV # Lo       HANGUL SYLLABLE MYE    */
  0xBAA8,			/* LV # Lo       HANGUL SYLLABLE MO     */
  0xBAC4,			/* LV # Lo       HANGUL SYLLABLE MWA    */
  0xBAE0,			/* LV # Lo       HANGUL SYLLABLE MWAE   */
  0xBAFC,			/* LV # Lo       HANGUL SYLLABLE MOE    */
  0xBB18,			/* LV # Lo       HANGUL SYLLABLE MYO    */
  0xBB34,			/* LV # Lo       HANGUL SYLLABLE MU     */
  0xBB50,			/* LV # Lo       HANGUL SYLLABLE MWEO   */
  0xBB6C,			/* LV # Lo       HANGUL SYLLABLE MWE    */
  0xBB88,			/* LV # Lo       HANGUL SYLLABLE MWI    */
  0xBBA4,			/* LV # Lo       HANGUL SYLLABLE MYU    */
  0xBBC0,			/* LV # Lo       HANGUL SYLLABLE MEU    */
  0xBBDC,			/* LV # Lo       HANGUL SYLLABLE MYI    */
  0xBBF8,			/* LV # Lo       HANGUL SYLLABLE MI     */
  0xBC14,			/* LV # Lo       HANGUL SYLLABLE BA     */
  0xBC30,			/* LV # Lo       HANGUL SYLLABLE BAE    */
  0xBC4C,			/* LV # Lo       HANGUL SYLLABLE BYA    */
  0xBC68,			/* LV # Lo       HANGUL SYLLABLE BYAE   */
  0xBC84,			/* LV # Lo       HANGUL SYLLABLE BEO    */
  0xBCA0,			/* LV # Lo       HANGUL SYLLABLE BE     */
  0xBCBC,			/* LV # Lo       HANGUL SYLLABLE BYEO   */
  0xBCD8,			/* LV # Lo       HANGUL SYLLABLE BYE    */
  0xBCF4,			/* LV # Lo       HANGUL SYLLABLE BO     */
  0xBD10,			/* LV # Lo       HANGUL SYLLABLE BWA    */
  0xBD2C,			/* LV # Lo       HANGUL SYLLABLE BWAE   */
  0xBD48,			/* LV # Lo       HANGUL SYLLABLE BOE    */
  0xBD64,			/* LV # Lo       HANGUL SYLLABLE BYO    */
  0xBD80,			/* LV # Lo       HANGUL SYLLABLE BU     */
  0xBD9C,			/* LV # Lo       HANGUL SYLLABLE BWEO   */
  0xBDB8,			/* LV # Lo       HANGUL SYLLABLE BWE    */
  0xBDD4,			/* LV # Lo       HANGUL SYLLABLE BWI    */
  0xBDF0,			/* LV # Lo       HANGUL SYLLABLE BYU    */
  0xBE0C,			/* LV # Lo       HANGUL SYLLABLE BEU    */
  0xBE28,			/* LV # Lo       HANGUL SYLLABLE BYI    */
  0xBE44,			/* LV # Lo       HANGUL SYLLABLE BI     */
  0xBE60,			/* LV # Lo       HANGUL SYLLABLE BBA    */
  0xBE7C,			/* LV # Lo       HANGUL SYLLABLE BBAE   */
  0xBE98,			/* LV # Lo       HANGUL SYLLABLE BBYA   */
  0xBEB4,			/* LV # Lo       HANGUL SYLLABLE BBYAE  */
  0xBED0,			/* LV # Lo       HANGUL SYLLABLE BBEO   */
  0xBEEC,			/* LV # Lo       HANGUL SYLLABLE BBE    */
  0xBF08,			/* LV # Lo       HANGUL SYLLABLE BBYEO  */
  0xBF24,			/* LV # Lo       HANGUL SYLLABLE BBYE   */
  0xBF40,			/* LV # Lo       HANGUL SYLLABLE BBO    */
  0xBF5C,			/* LV # Lo       HANGUL SYLLABLE BBWA   */
  0xBF78,			/* LV # Lo       HANGUL SYLLABLE BBWAE  */
  0xBF94,			/* LV # Lo       HANGUL SYLLABLE BBOE   */
  0xBFB0,			/* LV # Lo       HANGUL SYLLABLE BBYO   */
  0xBFCC,			/* LV # Lo       HANGUL SYLLABLE BBU    */
  0xBFE8,			/* LV # Lo       HANGUL SYLLABLE BBWEO  */
  0xC004,			/* LV # Lo       HANGUL SYLLABLE BBWE   */
  0xC020,			/* LV # Lo       HANGUL SYLLABLE BBWI   */
  0xC03C,			/* LV # Lo       HANGUL SYLLABLE BBYU   */
  0xC058,			/* LV # Lo       HANGUL SYLLABLE BBEU   */
  0xC074,			/* LV # Lo       HANGUL SYLLABLE BBYI   */
  0xC090,			/* LV # Lo       HANGUL SYLLABLE BBI    */
  0xC0AC,			/* LV # Lo       HANGUL SYLLABLE SA     */
  0xC0C8,			/* LV # Lo       HANGUL SYLLABLE SAE    */
  0xC0E4,			/* LV # Lo       HANGUL SYLLABLE SYA    */
  0xC100,			/* LV # Lo       HANGUL SYLLABLE SYAE   */
  0xC11C,			/* LV # Lo       HANGUL SYLLABLE SEO    */
  0xC138,			/* LV # Lo       HANGUL SYLLABLE SE     */
  0xC154,			/* LV # Lo       HANGUL SYLLABLE SYEO   */
  0xC170,			/* LV # Lo       HANGUL SYLLABLE SYE    */
  0xC18C,			/* LV # Lo       HANGUL SYLLABLE SO     */
  0xC1A8,			/* LV # Lo       HANGUL SYLLABLE SWA    */
  0xC1C4,			/* LV # Lo       HANGUL SYLLABLE SWAE   */
  0xC1E0,			/* LV # Lo       HANGUL SYLLABLE SOE    */
  0xC1FC,			/* LV # Lo       HANGUL SYLLABLE SYO    */
  0xC218,			/* LV # Lo       HANGUL SYLLABLE SU     */
  0xC234,			/* LV # Lo       HANGUL SYLLABLE SWEO   */
  0xC250,			/* LV # Lo       HANGUL SYLLABLE SWE    */
  0xC26C,			/* LV # Lo       HANGUL SYLLABLE SWI    */
  0xC288,			/* LV # Lo       HANGUL SYLLABLE SYU    */
  0xC2A4,			/* LV # Lo       HANGUL SYLLABLE SEU    */
  0xC2C0,			/* LV # Lo       HANGUL SYLLABLE SYI    */
  0xC2DC,			/* LV # Lo       HANGUL SYLLABLE SI     */
  0xC2F8,			/* LV # Lo       HANGUL SYLLABLE SSA    */
  0xC314,			/* LV # Lo       HANGUL SYLLABLE SSAE   */
  0xC330,			/* LV # Lo       HANGUL SYLLABLE SSYA   */
  0xC34C,			/* LV # Lo       HANGUL SYLLABLE SSYAE  */
  0xC368,			/* LV # Lo       HANGUL SYLLABLE SSEO   */
  0xC384,			/* LV # Lo       HANGUL SYLLABLE SSE    */
  0xC3A0,			/* LV # Lo       HANGUL SYLLABLE SSYEO  */
  0xC3BC,			/* LV # Lo       HANGUL SYLLABLE SSYE   */
  0xC3D8,			/* LV # Lo       HANGUL SYLLABLE SSO    */
  0xC3F4,			/* LV # Lo       HANGUL SYLLABLE SSWA   */
  0xC410,			/* LV # Lo       HANGUL SYLLABLE SSWAE  */
  0xC42C,			/* LV # Lo       HANGUL SYLLABLE SSOE   */
  0xC448,			/* LV # Lo       HANGUL SYLLABLE SSYO   */
  0xC464,			/* LV # Lo       HANGUL SYLLABLE SSU    */
  0xC480,			/* LV # Lo       HANGUL SYLLABLE SSWEO  */
  0xC49C,			/* LV # Lo       HANGUL SYLLABLE SSWE   */
  0xC4B8,			/* LV # Lo       HANGUL SYLLABLE SSWI   */
  0xC4D4,			/* LV # Lo       HANGUL SYLLABLE SSYU   */
  0xC4F0,			/* LV # Lo       HANGUL SYLLABLE SSEU   */
  0xC50C,			/* LV # Lo       HANGUL SYLLABLE SSYI   */
  0xC528,			/* LV # Lo       HANGUL SYLLABLE SSI    */
  0xC544,			/* LV # Lo       HANGUL SYLLABLE A      */
  0xC560,			/* LV # Lo       HANGUL SYLLABLE AE     */
  0xC57C,			/* LV # Lo       HANGUL SYLLABLE YA     */
  0xC598,			/* LV # Lo       HANGUL SYLLABLE YAE    */
  0xC5B4,			/* LV # Lo       HANGUL SYLLABLE EO     */
  0xC5D0,			/* LV # Lo       HANGUL SYLLABLE E      */
  0xC5EC,			/* LV # Lo       HANGUL SYLLABLE YEO    */
  0xC608,			/* LV # Lo       HANGUL SYLLABLE YE     */
  0xC624,			/* LV # Lo       HANGUL SYLLABLE O      */
  0xC640,			/* LV # Lo       HANGUL SYLLABLE WA     */
  0xC65C,			/* LV # Lo       HANGUL SYLLABLE WAE    */
  0xC678,			/* LV # Lo       HANGUL SYLLABLE OE     */
  0xC694,			/* LV # Lo       HANGUL SYLLABLE YO     */
  0xC6B0,			/* LV # Lo       HANGUL SYLLABLE U      */
  0xC6CC,			/* LV # Lo       HANGUL SYLLABLE WEO    */
  0xC6E8,			/* LV # Lo       HANGUL SYLLABLE WE     */
  0xC704,			/* LV # Lo       HANGUL SYLLABLE WI     */
  0xC720,			/* LV # Lo       HANGUL SYLLABLE YU     */
  0xC73C,			/* LV # Lo       HANGUL SYLLABLE EU     */
  0xC758,			/* LV # Lo       HANGUL SYLLABLE YI     */
  0xC774,			/* LV # Lo       HANGUL SYLLABLE I      */
  0xC790,			/* LV # Lo       HANGUL SYLLABLE JA     */
  0xC7AC,			/* LV # Lo       HANGUL SYLLABLE JAE    */
  0xC7C8,			/* LV # Lo       HANGUL SYLLABLE JYA    */
  0xC7E4,			/* LV # Lo       HANGUL SYLLABLE JYAE   */
  0xC800,			/* LV # Lo       HANGUL SYLLABLE JEO    */
  0xC81C,			/* LV # Lo       HANGUL SYLLABLE JE     */
  0xC838,			/* LV # Lo       HANGUL SYLLABLE JYEO   */
  0xC854,			/* LV # Lo       HANGUL SYLLABLE JYE    */
  0xC870,			/* LV # Lo       HANGUL SYLLABLE JO     */
  0xC88C,			/* LV # Lo       HANGUL SYLLABLE JWA    */
  0xC8A8,			/* LV # Lo       HANGUL SYLLABLE JWAE   */
  0xC8C4,			/* LV # Lo       HANGUL SYLLABLE JOE    */
  0xC8E0,			/* LV # Lo       HANGUL SYLLABLE JYO    */
  0xC8FC,			/* LV # Lo       HANGUL SYLLABLE JU     */
  0xC918,			/* LV # Lo       HANGUL SYLLABLE JWEO   */
  0xC934,			/* LV # Lo       HANGUL SYLLABLE JWE    */
  0xC950,			/* LV # Lo       HANGUL SYLLABLE JWI    */
  0xC96C,			/* LV # Lo       HANGUL SYLLABLE JYU    */
  0xC988,			/* LV # Lo       HANGUL SYLLABLE JEU    */
  0xC9A4,			/* LV # Lo       HANGUL SYLLABLE JYI    */
  0xC9C0,			/* LV # Lo       HANGUL SYLLABLE JI     */
  0xC9DC,			/* LV # Lo       HANGUL SYLLABLE JJA    */
  0xC9F8,			/* LV # Lo       HANGUL SYLLABLE JJAE   */
  0xCA14,			/* LV # Lo       HANGUL SYLLABLE JJYA   */
  0xCA30,			/* LV # Lo       HANGUL SYLLABLE JJYAE  */
  0xCA4C,			/* LV # Lo       HANGUL SYLLABLE JJEO   */
  0xCA68,			/* LV # Lo       HANGUL SYLLABLE JJE    */
  0xCA84,			/* LV # Lo       HANGUL SYLLABLE JJYEO  */
  0xCAA0,			/* LV # Lo       HANGUL SYLLABLE JJYE   */
  0xCABC,			/* LV # Lo       HANGUL SYLLABLE JJO    */
  0xCAD8,			/* LV # Lo       HANGUL SYLLABLE JJWA   */
  0xCAF4,			/* LV # Lo       HANGUL SYLLABLE JJWAE  */
  0xCB10,			/* LV # Lo       HANGUL SYLLABLE JJOE   */
  0xCB2C,			/* LV # Lo       HANGUL SYLLABLE JJYO   */
  0xCB48,			/* LV # Lo       HANGUL SYLLABLE JJU    */
  0xCB64,			/* LV # Lo       HANGUL SYLLABLE JJWEO  */
  0xCB80,			/* LV # Lo       HANGUL SYLLABLE JJWE   */
  0xCB9C,			/* LV # Lo       HANGUL SYLLABLE JJWI   */
  0xCBB8,			/* LV # Lo       HANGUL SYLLABLE JJYU   */
  0xCBD4,			/* LV # Lo       HANGUL SYLLABLE JJEU   */
  0xCBF0,			/* LV # Lo       HANGUL SYLLABLE JJYI   */
  0xCC0C,			/* LV # Lo       HANGUL SYLLABLE JJI    */
  0xCC28,			/* LV # Lo       HANGUL SYLLABLE CA     */
  0xCC44,			/* LV # Lo       HANGUL SYLLABLE CAE    */
  0xCC60,			/* LV # Lo       HANGUL SYLLABLE CYA    */
  0xCC7C,			/* LV # Lo       HANGUL SYLLABLE CYAE   */
  0xCC98,			/* LV # Lo       HANGUL SYLLABLE CEO    */
  0xCCB4,			/* LV # Lo       HANGUL SYLLABLE CE     */
  0xCCD0,			/* LV # Lo       HANGUL SYLLABLE CYEO   */
  0xCCEC,			/* LV # Lo       HANGUL SYLLABLE CYE    */
  0xCD08,			/* LV # Lo       HANGUL SYLLABLE CO     */
  0xCD24,			/* LV # Lo       HANGUL SYLLABLE CWA    */
  0xCD40,			/* LV # Lo       HANGUL SYLLABLE CWAE   */
  0xCD5C,			/* LV # Lo       HANGUL SYLLABLE COE    */
  0xCD78,			/* LV # Lo       HANGUL SYLLABLE CYO    */
  0xCD94,			/* LV # Lo       HANGUL SYLLABLE CU     */
  0xCDB0,			/* LV # Lo       HANGUL SYLLABLE CWEO   */
  0xCDCC,			/* LV # Lo       HANGUL SYLLABLE CWE    */
  0xCDE8,			/* LV # Lo       HANGUL SYLLABLE CWI    */
  0xCE04,			/* LV # Lo       HANGUL SYLLABLE CYU    */
  0xCE20,			/* LV # Lo       HANGUL SYLLABLE CEU    */
  0xCE3C,			/* LV # Lo       HANGUL SYLLABLE CYI    */
  0xCE58,			/* LV # Lo       HANGUL SYLLABLE CI     */
  0xCE74,			/* LV # Lo       HANGUL SYLLABLE KA     */
  0xCE90,			/* LV # Lo       HANGUL SYLLABLE KAE    */
  0xCEAC,			/* LV # Lo       HANGUL SYLLABLE KYA    */
  0xCEC8,			/* LV # Lo       HANGUL SYLLABLE KYAE   */
  0xCEE4,			/* LV # Lo       HANGUL SYLLABLE KEO    */
  0xCF00,			/* LV # Lo       HANGUL SYLLABLE KE     */
  0xCF1C,			/* LV # Lo       HANGUL SYLLABLE KYEO   */
  0xCF38,			/* LV # Lo       HANGUL SYLLABLE KYE    */
  0xCF54,			/* LV # Lo       HANGUL SYLLABLE KO     */
  0xCF70,			/* LV # Lo       HANGUL SYLLABLE KWA    */
  0xCF8C,			/* LV # Lo       HANGUL SYLLABLE KWAE   */
  0xCFA8,			/* LV # Lo       HANGUL SYLLABLE KOE    */
  0xCFC4,			/* LV # Lo       HANGUL SYLLABLE KYO    */
  0xCFE0,			/* LV # Lo       HANGUL SYLLABLE KU     */
  0xCFFC,			/* LV # Lo       HANGUL SYLLABLE KWEO   */
  0xD018,			/* LV # Lo       HANGUL SYLLABLE KWE    */
  0xD034,			/* LV # Lo       HANGUL SYLLABLE KWI    */
  0xD050,			/* LV # Lo       HANGUL SYLLABLE KYU    */
  0xD06C,			/* LV # Lo       HANGUL SYLLABLE KEU    */
  0xD088,			/* LV # Lo       HANGUL SYLLABLE KYI    */
  0xD0A4,			/* LV # Lo       HANGUL SYLLABLE KI     */
  0xD0C0,			/* LV # Lo       HANGUL SYLLABLE TA     */
  0xD0DC,			/* LV # Lo       HANGUL SYLLABLE TAE    */
  0xD0F8,			/* LV # Lo       HANGUL SYLLABLE TYA    */
  0xD114,			/* LV # Lo       HANGUL SYLLABLE TYAE   */
  0xD130,			/* LV # Lo       HANGUL SYLLABLE TEO    */
  0xD14C,			/* LV # Lo       HANGUL SYLLABLE TE     */
  0xD168,			/* LV # Lo       HANGUL SYLLABLE TYEO   */
  0xD184,			/* LV # Lo       HANGUL SYLLABLE TYE    */
  0xD1A0,			/* LV # Lo       HANGUL SYLLABLE TO     */
  0xD1BC,			/* LV # Lo       HANGUL SYLLABLE TWA    */
  0xD1D8,			/* LV # Lo       HANGUL SYLLABLE TWAE   */
  0xD1F4,			/* LV # Lo       HANGUL SYLLABLE TOE    */
  0xD210,			/* LV # Lo       HANGUL SYLLABLE TYO    */
  0xD22C,			/* LV # Lo       HANGUL SYLLABLE TU     */
  0xD248,			/* LV # Lo       HANGUL SYLLABLE TWEO   */
  0xD264,			/* LV # Lo       HANGUL SYLLABLE TWE    */
  0xD280,			/* LV # Lo       HANGUL SYLLABLE TWI    */
  0xD29C,			/* LV # Lo       HANGUL SYLLABLE TYU    */
  0xD2B8,			/* LV # Lo       HANGUL SYLLABLE TEU    */
  0xD2D4,			/* LV # Lo       HANGUL SYLLABLE TYI    */
  0xD2F0,			/* LV # Lo       HANGUL SYLLABLE TI     */
  0xD30C,			/* LV # Lo       HANGUL SYLLABLE PA     */
  0xD328,			/* LV # Lo       HANGUL SYLLABLE PAE    */
  0xD344,			/* LV # Lo       HANGUL SYLLABLE PYA    */
  0xD360,			/* LV # Lo       HANGUL SYLLABLE PYAE   */
  0xD37C,			/* LV # Lo       HANGUL SYLLABLE PEO    */
  0xD398,			/* LV # Lo       HANGUL SYLLABLE PE     */
  0xD3B4,			/* LV # Lo       HANGUL SYLLABLE PYEO   */
  0xD3D0,			/* LV # Lo       HANGUL SYLLABLE PYE    */
  0xD3EC,			/* LV # Lo       HANGUL SYLLABLE PO     */
  0xD408,			/* LV # Lo       HANGUL SYLLABLE PWA    */
  0xD424,			/* LV # Lo       HANGUL SYLLABLE PWAE   */
  0xD440,			/* LV # Lo       HANGUL SYLLABLE POE    */
  0xD45C,			/* LV # Lo       HANGUL SYLLABLE PYO    */
  0xD478,			/* LV # Lo       HANGUL SYLLABLE PU     */
  0xD494,			/* LV # Lo       HANGUL SYLLABLE PWEO   */
  0xD4B0,			/* LV # Lo       HANGUL SYLLABLE PWE    */
  0xD4CC,			/* LV # Lo       HANGUL SYLLABLE PWI    */
  0xD4E8,			/* LV # Lo       HANGUL SYLLABLE PYU    */
  0xD504,			/* LV # Lo       HANGUL SYLLABLE PEU    */
  0xD520,			/* LV # Lo       HANGUL SYLLABLE PYI    */
  0xD53C,			/* LV # Lo       HANGUL SYLLABLE PI     */
  0xD558,			/* LV # Lo       HANGUL SYLLABLE HA     */
  0xD574,			/* LV # Lo       HANGUL SYLLABLE HAE    */
  0xD590,			/* LV # Lo       HANGUL SYLLABLE HYA    */
  0xD5AC,			/* LV # Lo       HANGUL SYLLABLE HYAE   */
  0xD5C8,			/* LV # Lo       HANGUL SYLLABLE HEO    */
  0xD5E4,			/* LV # Lo       HANGUL SYLLABLE HE     */
  0xD600,			/* LV # Lo       HANGUL SYLLABLE HYEO   */
  0xD61C,			/* LV # Lo       HANGUL SYLLABLE HYE    */
  0xD638,			/* LV # Lo       HANGUL SYLLABLE HO     */
  0xD654,			/* LV # Lo       HANGUL SYLLABLE HWA    */
  0xD670,			/* LV # Lo       HANGUL SYLLABLE HWAE   */
  0xD68C,			/* LV # Lo       HANGUL SYLLABLE HOE    */
  0xD6A8,			/* LV # Lo       HANGUL SYLLABLE HYO    */
  0xD6C4,			/* LV # Lo       HANGUL SYLLABLE HU     */
  0xD6E0,			/* LV # Lo       HANGUL SYLLABLE HWEO   */
  0xD6FC,			/* LV # Lo       HANGUL SYLLABLE HWE    */
  0xD718,			/* LV # Lo       HANGUL SYLLABLE HWI    */
  0xD734,			/* LV # Lo       HANGUL SYLLABLE HYU    */
  0xD750,			/* LV # Lo       HANGUL SYLLABLE HEU    */
  0xD76C,			/* LV # Lo       HANGUL SYLLABLE HYI    */
  0xD788,			/* LV # Lo       HANGUL SYLLABLE HI     */
  0
};

static const uint32_t pr29_13_2[] = {
  0x11A8, 0x11A9, 0x11AA, 0x11AB, 0x11AC, 0x11AD, 0x11AE, 0x11AF,
  0x11B0, 0x11B1, 0x11B2, 0x11B3, 0x11B4, 0x11B5, 0x11B6, 0x11B7,
  0x11B8, 0x11B9, 0x11BA, 0x11BB, 0x11BC, 0x11BD, 0x11BE, 0x11BF,
  0x11C0, 0x11C1, 0x11C2, 0
};

typedef struct
{
  const uint32_t *first;
  const uint32_t *last;
} Pr29;

static const Pr29 pr29[] = {
  {&pr29_1_1[0], &pr29_1_2[0]},
  {&pr29_2_1[0], &pr29_2_2[0]},
  {&pr29_3_1[0], &pr29_3_2[0]},
  {&pr29_4_1[0], &pr29_4_2[0]},
  {&pr29_5_1[0], &pr29_5_2[0]},
  {&pr29_6_1[0], &pr29_6_2[0]},
  {&pr29_7_1[0], &pr29_7_2[0]},
  {&pr29_8_1[0], &pr29_8_2[0]},
  {&pr29_9_1[0], &pr29_9_2[0]},
  {&pr29_10_1[0], &pr29_10_2[0]},
  {&pr29_11_1[0], &pr29_11_2[0]},
  {&pr29_12_1[0], &pr29_12_2[0]},
  {&pr29_13_1[0], &pr29_13_2[0]},
  {NULL, NULL}
};

static size_t
first_column (uint32_t c)
{
  size_t i, j;

  for (i = 0; pr29[i].first; i++)
    for (j = 0; pr29[i].first[j]; j++)
      if (c == pr29[i].first[j])
	return i + 1;

  return 0;
}

static int
in_last_column_row (uint32_t c, size_t row)
{
  size_t i;

  for (i = 0; pr29[row - 1].last[i]; i++)
    if (c == pr29[row - 1].last[i])
      return 1;

  return 0;
}

static size_t
combinationclass (uint32_t c)
{
  size_t i;

  for (i = 0; nzcc[i]; i++)
    if (c == nzcc[i])
      return i + 1;

  return 0;
}

/**
 * pr29_4:
 * @in: input array with unicode code points.
 * @len: length of input array with unicode code points.
 *
 * Check the input to see if it may be normalized into different
 * strings by different NFKC implementations, due to an anomaly in the
 * NFKC specifications.
 *
 * Return value: Returns the #Pr29_rc value %PR29_SUCCESS on success,
 *   and %PR29_PROBLEM if the input sequence is a "problem sequence"
 *   (i.e., may be normalized into different strings by different
 *   implementations).
 **/
int
pr29_4 (const uint32_t * in, size_t len)
{
  size_t i, j, k, row;

  /*
   * The problem sequence are of the form:
   *
   *      first_character  intervening_character+ last_character
   *
   * where the first_character and last_character come from the same
   * row in the following table, and there is at least one
   * intervening_character with non-zero Canonical Combining
   * Class. (The '+' above means one or more occurrences.)
   *
   */

  for (i = 0; i < len; i++)
    if ((row = first_column (in[i])) > 0)
      for (j = i + 1; j < len; j++)
	if (combinationclass (in[j]))
	  for (k = j + 1; k < len; k++)
	    if (in_last_column_row (in[k], row))
	      return PR29_PROBLEM;

  return PR29_SUCCESS;
}

/**
 * pr29_4z:
 * @in: zero terminated array of Unicode code points.
 *
 * Check the input to see if it may be normalized into different
 * strings by different NFKC implementations, due to an anomaly in the
 * NFKC specifications.
 *
 * Return value: Returns the #Pr29_rc value %PR29_SUCCESS on success,
 *   and %PR29_PROBLEM if the input sequence is a "problem sequence"
 *   (i.e., may be normalized into different strings by different
 *   implementations).
 **/
int
pr29_4z (const uint32_t * in)
{
  size_t len;

  for (len = 0; in[len]; len++)
    ;

  return pr29_4 (in, len);
}

/**
 * pr29_8z:
 * @in: zero terminated input UTF-8 string.
 *
 * Check the input to see if it may be normalized into different
 * strings by different NFKC implementations, due to an anomaly in the
 * NFKC specifications.
 *
 * Return value: Returns the #Pr29_rc value %PR29_SUCCESS on success,
 *   and %PR29_PROBLEM if the input sequence is a "problem sequence"
 *   (i.e., may be normalized into different strings by different
 *   implementations), or %PR29_STRINGPREP_ERROR if there was a
 *   problem converting the string from UTF-8 to UCS-4.
 **/
int
pr29_8z (const char *in)
{
  uint32_t *p;
  int rc;

  p = stringprep_utf8_to_ucs4 (in, -1, NULL);
  if (!p)
    return PR29_STRINGPREP_ERROR;

  rc = pr29_4z (p);

  free (p);

  return rc;
}

/**
 * Pr29_rc:
 * @PR29_SUCCESS: Successful operation.  This value is guaranteed to
 *   always be zero, the remaining ones are only guaranteed to hold
 *   non-zero values, for logical comparison purposes.
 * @PR29_PROBLEM: A problem sequence was encountered.
 * @PR29_STRINGPREP_ERROR: The character set conversion failed (only
 *   for pr29_8z()).
 *
 * Enumerated return codes for pr29_4(), pr29_4z(), pr29_8z().  The
 * value 0 is guaranteed to always correspond to success.
 */
