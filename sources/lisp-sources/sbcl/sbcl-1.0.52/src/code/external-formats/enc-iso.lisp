(in-package "SB!IMPL")

(define-unibyte-mapping-external-format :iso-8859-2
    (:|iso-8859-2| :latin-2 :|latin-2|)
  (#xA1 #x0104) ; LATIN CAPITAL LETTER A WITH OGONEK
  (#xA2 #x02D8) ; BREVE
  (#xA3 #x0141) ; LATIN CAPITAL LETTER L WITH STROKE
  (#xA5 #x013D) ; LATIN CAPITAL LETTER L WITH CARON
  (#xA6 #x015A) ; LATIN CAPITAL LETTER S WITH ACUTE
  (#xA9 #x0160) ; LATIN CAPITAL LETTER S WITH CARON
  (#xAA #x015E) ; LATIN CAPITAL LETTER S WITH CEDILLA
  (#xAB #x0164) ; LATIN CAPITAL LETTER T WITH CARON
  (#xAC #x0179) ; LATIN CAPITAL LETTER Z WITH ACUTE
  (#xAE #x017D) ; LATIN CAPITAL LETTER Z WITH CARON
  (#xAF #x017B) ; LATIN CAPITAL LETTER Z WITH DOT ABOVE
  (#xB1 #x0105) ; LATIN SMALL LETTER A WITH OGONEK
  (#xB2 #x02DB) ; OGONEK
  (#xB3 #x0142) ; LATIN SMALL LETTER L WITH STROKE
  (#xB5 #x013E) ; LATIN SMALL LETTER L WITH CARON
  (#xB6 #x015B) ; LATIN SMALL LETTER S WITH ACUTE
  (#xB7 #x02C7) ; CARON
  (#xB9 #x0161) ; LATIN SMALL LETTER S WITH CARON
  (#xBA #x015F) ; LATIN SMALL LETTER S WITH CEDILLA
  (#xBB #x0165) ; LATIN SMALL LETTER T WITH CARON
  (#xBC #x017A) ; LATIN SMALL LETTER Z WITH ACUTE
  (#xBD #x02DD) ; DOUBLE ACUTE ACCENT
  (#xBE #x017E) ; LATIN SMALL LETTER Z WITH CARON
  (#xBF #x017C) ; LATIN SMALL LETTER Z WITH DOT ABOVE
  (#xC0 #x0154) ; LATIN CAPITAL LETTER R WITH ACUTE
  (#xC3 #x0102) ; LATIN CAPITAL LETTER A WITH BREVE
  (#xC5 #x0139) ; LATIN CAPITAL LETTER L WITH ACUTE
  (#xC6 #x0106) ; LATIN CAPITAL LETTER C WITH ACUTE
  (#xC8 #x010C) ; LATIN CAPITAL LETTER C WITH CARON
  (#xCA #x0118) ; LATIN CAPITAL LETTER E WITH OGONEK
  (#xCC #x011A) ; LATIN CAPITAL LETTER E WITH CARON
  (#xCF #x010E) ; LATIN CAPITAL LETTER D WITH CARON
  (#xD0 #x0110) ; LATIN CAPITAL LETTER D WITH STROKE
  (#xD1 #x0143) ; LATIN CAPITAL LETTER N WITH ACUTE
  (#xD2 #x0147) ; LATIN CAPITAL LETTER N WITH CARON
  (#xD5 #x0150) ; LATIN CAPITAL LETTER O WITH DOUBLE ACUTE
  (#xD8 #x0158) ; LATIN CAPITAL LETTER R WITH CARON
  (#xD9 #x016E) ; LATIN CAPITAL LETTER U WITH RING ABOVE
  (#xDB #x0170) ; LATIN CAPITAL LETTER U WITH DOUBLE ACUTE
  (#xDE #x0162) ; LATIN CAPITAL LETTER T WITH CEDILLA
  (#xE0 #x0155) ; LATIN SMALL LETTER R WITH ACUTE
  (#xE3 #x0103) ; LATIN SMALL LETTER A WITH BREVE
  (#xE5 #x013A) ; LATIN SMALL LETTER L WITH ACUTE
  (#xE6 #x0107) ; LATIN SMALL LETTER C WITH ACUTE
  (#xE8 #x010D) ; LATIN SMALL LETTER C WITH CARON
  (#xEA #x0119) ; LATIN SMALL LETTER E WITH OGONEK
  (#xEC #x011B) ; LATIN SMALL LETTER E WITH CARON
  (#xEF #x010F) ; LATIN SMALL LETTER D WITH CARON
  (#xF0 #x0111) ; LATIN SMALL LETTER D WITH STROKE
  (#xF1 #x0144) ; LATIN SMALL LETTER N WITH ACUTE
  (#xF2 #x0148) ; LATIN SMALL LETTER N WITH CARON
  (#xF5 #x0151) ; LATIN SMALL LETTER O WITH DOUBLE ACUTE
  (#xF8 #x0159) ; LATIN SMALL LETTER R WITH CARON
  (#xF9 #x016F) ; LATIN SMALL LETTER U WITH RING ABOVE
  (#xFB #x0171) ; LATIN SMALL LETTER U WITH DOUBLE ACUTE
  (#xFE #x0163) ; LATIN SMALL LETTER T WITH CEDILLA
  (#xFF #x02D9) ; DOT ABOVE
)

(define-unibyte-mapping-external-format :iso-8859-3
    (:|iso-8859-3| :latin-3 :|latin-3|)
  (#xA1 #x0126) ; LATIN CAPITAL LETTER H WITH STROKE
  (#xA2 #x02D8) ; BREVE
  (#xA5 nil)
  (#xA6 #x0124) ; LATIN CAPITAL LETTER H WITH CIRCUMFLEX
  (#xA9 #x0130) ; LATIN CAPITAL LETTER I WITH DOT ABOVE
  (#xAA #x015E) ; LATIN CAPITAL LETTER S WITH CEDILLA
  (#xAB #x011E) ; LATIN CAPITAL LETTER G WITH BREVE
  (#xAC #x0134) ; LATIN CAPITAL LETTER J WITH CIRCUMFLEX
  (#xAE nil)
  (#xAF #x017B) ; LATIN CAPITAL LETTER Z WITH DOT ABOVE
  (#xB1 #x0127) ; LATIN SMALL LETTER H WITH STROKE
  (#xB6 #x0125) ; LATIN SMALL LETTER H WITH CIRCUMFLEX
  (#xB9 #x0131) ; LATIN SMALL LETTER DOTLESS I
  (#xBA #x015F) ; LATIN SMALL LETTER S WITH CEDILLA
  (#xBB #x011F) ; LATIN SMALL LETTER G WITH BREVE
  (#xBC #x0135) ; LATIN SMALL LETTER J WITH CIRCUMFLEX
  (#xBE nil)
  (#xBF #x017C) ; LATIN SMALL LETTER Z WITH DOT ABOVE
  (#xC3 nil)
  (#xC5 #x010A) ; LATIN CAPITAL LETTER C WITH DOT ABOVE
  (#xC6 #x0108) ; LATIN CAPITAL LETTER C WITH CIRCUMFLEX
  (#xD0 nil)
  (#xD5 #x0120) ; LATIN CAPITAL LETTER G WITH DOT ABOVE
  (#xD8 #x011C) ; LATIN CAPITAL LETTER G WITH CIRCUMFLEX
  (#xDD #x016C) ; LATIN CAPITAL LETTER U WITH BREVE
  (#xDE #x015C) ; LATIN CAPITAL LETTER S WITH CIRCUMFLEX
  (#xE3 nil)
  (#xE5 #x010B) ; LATIN SMALL LETTER C WITH DOT ABOVE
  (#xE6 #x0109) ; LATIN SMALL LETTER C WITH CIRCUMFLEX
  (#xF0 nil)
  (#xF5 #x0121) ; LATIN SMALL LETTER G WITH DOT ABOVE
  (#xF8 #x011D) ; LATIN SMALL LETTER G WITH CIRCUMFLEX
  (#xFD #x016D) ; LATIN SMALL LETTER U WITH BREVE
  (#xFE #x015D) ; LATIN SMALL LETTER S WITH CIRCUMFLEX
  (#xFF #x02D9) ; DOT ABOVE
)

(define-unibyte-mapping-external-format :iso-8859-4
    (:|iso-8859-4| :latin-4 :|latin-4|)
  (#xA1 #x0104) ; LATIN CAPITAL LETTER A WITH OGONEK
  (#xA2 #x0138) ; LATIN SMALL LETTER KRA
  (#xA3 #x0156) ; LATIN CAPITAL LETTER R WITH CEDILLA
  (#xA5 #x0128) ; LATIN CAPITAL LETTER I WITH TILDE
  (#xA6 #x013B) ; LATIN CAPITAL LETTER L WITH CEDILLA
  (#xA9 #x0160) ; LATIN CAPITAL LETTER S WITH CARON
  (#xAA #x0112) ; LATIN CAPITAL LETTER E WITH MACRON
  (#xAB #x0122) ; LATIN CAPITAL LETTER G WITH CEDILLA
  (#xAC #x0166) ; LATIN CAPITAL LETTER T WITH STROKE
  (#xAE #x017D) ; LATIN CAPITAL LETTER Z WITH CARON
  (#xB1 #x0105) ; LATIN SMALL LETTER A WITH OGONEK
  (#xB2 #x02DB) ; OGONEK
  (#xB3 #x0157) ; LATIN SMALL LETTER R WITH CEDILLA
  (#xB5 #x0129) ; LATIN SMALL LETTER I WITH TILDE
  (#xB6 #x013C) ; LATIN SMALL LETTER L WITH CEDILLA
  (#xB7 #x02C7) ; CARON
  (#xB9 #x0161) ; LATIN SMALL LETTER S WITH CARON
  (#xBA #x0113) ; LATIN SMALL LETTER E WITH MACRON
  (#xBB #x0123) ; LATIN SMALL LETTER G WITH CEDILLA
  (#xBC #x0167) ; LATIN SMALL LETTER T WITH STROKE
  (#xBD #x014A) ; LATIN CAPITAL LETTER ENG
  (#xBE #x017E) ; LATIN SMALL LETTER Z WITH CARON
  (#xBF #x014B) ; LATIN SMALL LETTER ENG
  (#xC0 #x0100) ; LATIN CAPITAL LETTER A WITH MACRON
  (#xC7 #x012E) ; LATIN CAPITAL LETTER I WITH OGONEK
  (#xC8 #x010C) ; LATIN CAPITAL LETTER C WITH CARON
  (#xCA #x0118) ; LATIN CAPITAL LETTER E WITH OGONEK
  (#xCC #x0116) ; LATIN CAPITAL LETTER E WITH DOT ABOVE
  (#xCF #x012A) ; LATIN CAPITAL LETTER I WITH MACRON
  (#xD0 #x0110) ; LATIN CAPITAL LETTER D WITH STROKE
  (#xD1 #x0145) ; LATIN CAPITAL LETTER N WITH CEDILLA
  (#xD2 #x014C) ; LATIN CAPITAL LETTER O WITH MACRON
  (#xD3 #x0136) ; LATIN CAPITAL LETTER K WITH CEDILLA
  (#xD9 #x0172) ; LATIN CAPITAL LETTER U WITH OGONEK
  (#xDD #x0168) ; LATIN CAPITAL LETTER U WITH TILDE
  (#xDE #x016A) ; LATIN CAPITAL LETTER U WITH MACRON
  (#xE0 #x0101) ; LATIN SMALL LETTER A WITH MACRON
  (#xE7 #x012F) ; LATIN SMALL LETTER I WITH OGONEK
  (#xE8 #x010D) ; LATIN SMALL LETTER C WITH CARON
  (#xEA #x0119) ; LATIN SMALL LETTER E WITH OGONEK
  (#xEC #x0117) ; LATIN SMALL LETTER E WITH DOT ABOVE
  (#xEF #x012B) ; LATIN SMALL LETTER I WITH MACRON
  (#xF0 #x0111) ; LATIN SMALL LETTER D WITH STROKE
  (#xF1 #x0146) ; LATIN SMALL LETTER N WITH CEDILLA
  (#xF2 #x014D) ; LATIN SMALL LETTER O WITH MACRON
  (#xF3 #x0137) ; LATIN SMALL LETTER K WITH CEDILLA
  (#xF9 #x0173) ; LATIN SMALL LETTER U WITH OGONEK
  (#xFD #x0169) ; LATIN SMALL LETTER U WITH TILDE
  (#xFE #x016B) ; LATIN SMALL LETTER U WITH MACRON
  (#xFF #x02D9) ; DOT ABOVE
)

(define-unibyte-mapping-external-format :iso-8859-5 (:|iso-8859-5|)
  (#xA1 #x0401) ; CYRILLIC CAPITAL LETTER IO
  (#xA2 #x0402) ; CYRILLIC CAPITAL LETTER DJE
  (#xA3 #x0403) ; CYRILLIC CAPITAL LETTER GJE
  (#xA4 #x0404) ; CYRILLIC CAPITAL LETTER UKRAINIAN IE
  (#xA5 #x0405) ; CYRILLIC CAPITAL LETTER DZE
  (#xA6 #x0406) ; CYRILLIC CAPITAL LETTER BYELORUSSIAN-UKRAINIAN I
  (#xA7 #x0407) ; CYRILLIC CAPITAL LETTER YI
  (#xA8 #x0408) ; CYRILLIC CAPITAL LETTER JE
  (#xA9 #x0409) ; CYRILLIC CAPITAL LETTER LJE
  (#xAA #x040A) ; CYRILLIC CAPITAL LETTER NJE
  (#xAB #x040B) ; CYRILLIC CAPITAL LETTER TSHE
  (#xAC #x040C) ; CYRILLIC CAPITAL LETTER KJE
  (#xAE #x040E) ; CYRILLIC CAPITAL LETTER SHORT U
  (#xAF #x040F) ; CYRILLIC CAPITAL LETTER DZHE
  (#xB0 #x0410) ; CYRILLIC CAPITAL LETTER A
  (#xB1 #x0411) ; CYRILLIC CAPITAL LETTER BE
  (#xB2 #x0412) ; CYRILLIC CAPITAL LETTER VE
  (#xB3 #x0413) ; CYRILLIC CAPITAL LETTER GHE
  (#xB4 #x0414) ; CYRILLIC CAPITAL LETTER DE
  (#xB5 #x0415) ; CYRILLIC CAPITAL LETTER IE
  (#xB6 #x0416) ; CYRILLIC CAPITAL LETTER ZHE
  (#xB7 #x0417) ; CYRILLIC CAPITAL LETTER ZE
  (#xB8 #x0418) ; CYRILLIC CAPITAL LETTER I
  (#xB9 #x0419) ; CYRILLIC CAPITAL LETTER SHORT I
  (#xBA #x041A) ; CYRILLIC CAPITAL LETTER KA
  (#xBB #x041B) ; CYRILLIC CAPITAL LETTER EL
  (#xBC #x041C) ; CYRILLIC CAPITAL LETTER EM
  (#xBD #x041D) ; CYRILLIC CAPITAL LETTER EN
  (#xBE #x041E) ; CYRILLIC CAPITAL LETTER O
  (#xBF #x041F) ; CYRILLIC CAPITAL LETTER PE
  (#xC0 #x0420) ; CYRILLIC CAPITAL LETTER ER
  (#xC1 #x0421) ; CYRILLIC CAPITAL LETTER ES
  (#xC2 #x0422) ; CYRILLIC CAPITAL LETTER TE
  (#xC3 #x0423) ; CYRILLIC CAPITAL LETTER U
  (#xC4 #x0424) ; CYRILLIC CAPITAL LETTER EF
  (#xC5 #x0425) ; CYRILLIC CAPITAL LETTER HA
  (#xC6 #x0426) ; CYRILLIC CAPITAL LETTER TSE
  (#xC7 #x0427) ; CYRILLIC CAPITAL LETTER CHE
  (#xC8 #x0428) ; CYRILLIC CAPITAL LETTER SHA
  (#xC9 #x0429) ; CYRILLIC CAPITAL LETTER SHCHA
  (#xCA #x042A) ; CYRILLIC CAPITAL LETTER HARD SIGN
  (#xCB #x042B) ; CYRILLIC CAPITAL LETTER YERU
  (#xCC #x042C) ; CYRILLIC CAPITAL LETTER SOFT SIGN
  (#xCD #x042D) ; CYRILLIC CAPITAL LETTER E
  (#xCE #x042E) ; CYRILLIC CAPITAL LETTER YU
  (#xCF #x042F) ; CYRILLIC CAPITAL LETTER YA
  (#xD0 #x0430) ; CYRILLIC SMALL LETTER A
  (#xD1 #x0431) ; CYRILLIC SMALL LETTER BE
  (#xD2 #x0432) ; CYRILLIC SMALL LETTER VE
  (#xD3 #x0433) ; CYRILLIC SMALL LETTER GHE
  (#xD4 #x0434) ; CYRILLIC SMALL LETTER DE
  (#xD5 #x0435) ; CYRILLIC SMALL LETTER IE
  (#xD6 #x0436) ; CYRILLIC SMALL LETTER ZHE
  (#xD7 #x0437) ; CYRILLIC SMALL LETTER ZE
  (#xD8 #x0438) ; CYRILLIC SMALL LETTER I
  (#xD9 #x0439) ; CYRILLIC SMALL LETTER SHORT I
  (#xDA #x043A) ; CYRILLIC SMALL LETTER KA
  (#xDB #x043B) ; CYRILLIC SMALL LETTER EL
  (#xDC #x043C) ; CYRILLIC SMALL LETTER EM
  (#xDD #x043D) ; CYRILLIC SMALL LETTER EN
  (#xDE #x043E) ; CYRILLIC SMALL LETTER O
  (#xDF #x043F) ; CYRILLIC SMALL LETTER PE
  (#xE0 #x0440) ; CYRILLIC SMALL LETTER ER
  (#xE1 #x0441) ; CYRILLIC SMALL LETTER ES
  (#xE2 #x0442) ; CYRILLIC SMALL LETTER TE
  (#xE3 #x0443) ; CYRILLIC SMALL LETTER U
  (#xE4 #x0444) ; CYRILLIC SMALL LETTER EF
  (#xE5 #x0445) ; CYRILLIC SMALL LETTER HA
  (#xE6 #x0446) ; CYRILLIC SMALL LETTER TSE
  (#xE7 #x0447) ; CYRILLIC SMALL LETTER CHE
  (#xE8 #x0448) ; CYRILLIC SMALL LETTER SHA
  (#xE9 #x0449) ; CYRILLIC SMALL LETTER SHCHA
  (#xEA #x044A) ; CYRILLIC SMALL LETTER HARD SIGN
  (#xEB #x044B) ; CYRILLIC SMALL LETTER YERU
  (#xEC #x044C) ; CYRILLIC SMALL LETTER SOFT SIGN
  (#xED #x044D) ; CYRILLIC SMALL LETTER E
  (#xEE #x044E) ; CYRILLIC SMALL LETTER YU
  (#xEF #x044F) ; CYRILLIC SMALL LETTER YA
  (#xF0 #x2116) ; NUMERO SIGN
  (#xF1 #x0451) ; CYRILLIC SMALL LETTER IO
  (#xF2 #x0452) ; CYRILLIC SMALL LETTER DJE
  (#xF3 #x0453) ; CYRILLIC SMALL LETTER GJE
  (#xF4 #x0454) ; CYRILLIC SMALL LETTER UKRAINIAN IE
  (#xF5 #x0455) ; CYRILLIC SMALL LETTER DZE
  (#xF6 #x0456) ; CYRILLIC SMALL LETTER BYELORUSSIAN-UKRAINIAN I
  (#xF7 #x0457) ; CYRILLIC SMALL LETTER YI
  (#xF8 #x0458) ; CYRILLIC SMALL LETTER JE
  (#xF9 #x0459) ; CYRILLIC SMALL LETTER LJE
  (#xFA #x045A) ; CYRILLIC SMALL LETTER NJE
  (#xFB #x045B) ; CYRILLIC SMALL LETTER TSHE
  (#xFC #x045C) ; CYRILLIC SMALL LETTER KJE
  (#xFD #x00A7) ; SECTION SIGN
  (#xFE #x045E) ; CYRILLIC SMALL LETTER SHORT U
  (#xFF #x045F) ; CYRILLIC SMALL LETTER DZHE
)

(define-unibyte-mapping-external-format :iso-8859-6 (:|iso-8859-6|)
  (#xA1 nil)
  (#xA2 nil)
  (#xA3 nil)
  (#xA5 nil)
  (#xA6 nil)
  (#xA7 nil)
  (#xA8 nil)
  (#xA9 nil)
  (#xAA nil)
  (#xAB nil)
  (#xAC #x060C) ; ARABIC COMMA
  (#xAE nil)
  (#xAF nil)
  (#xB0 nil)
  (#xB1 nil)
  (#xB2 nil)
  (#xB3 nil)
  (#xB4 nil)
  (#xB5 nil)
  (#xB6 nil)
  (#xB7 nil)
  (#xB8 nil)
  (#xB9 nil)
  (#xBA nil)
  (#xBB #x061B) ; ARABIC SEMICOLON
  (#xBC nil)
  (#xBD nil)
  (#xBE nil)
  (#xBF #x061F) ; ARABIC QUESTION MARK
  (#xC0 nil)
  (#xC1 #x0621) ; ARABIC LETTER HAMZA
  (#xC2 #x0622) ; ARABIC LETTER ALEF WITH MADDA ABOVE
  (#xC3 #x0623) ; ARABIC LETTER ALEF WITH HAMZA ABOVE
  (#xC4 #x0624) ; ARABIC LETTER WAW WITH HAMZA ABOVE
  (#xC5 #x0625) ; ARABIC LETTER ALEF WITH HAMZA BELOW
  (#xC6 #x0626) ; ARABIC LETTER YEH WITH HAMZA ABOVE
  (#xC7 #x0627) ; ARABIC LETTER ALEF
  (#xC8 #x0628) ; ARABIC LETTER BEH
  (#xC9 #x0629) ; ARABIC LETTER TEH MARBUTA
  (#xCA #x062A) ; ARABIC LETTER TEH
  (#xCB #x062B) ; ARABIC LETTER THEH
  (#xCC #x062C) ; ARABIC LETTER JEEM
  (#xCD #x062D) ; ARABIC LETTER HAH
  (#xCE #x062E) ; ARABIC LETTER KHAH
  (#xCF #x062F) ; ARABIC LETTER DAL
  (#xD0 #x0630) ; ARABIC LETTER THAL
  (#xD1 #x0631) ; ARABIC LETTER REH
  (#xD2 #x0632) ; ARABIC LETTER ZAIN
  (#xD3 #x0633) ; ARABIC LETTER SEEN
  (#xD4 #x0634) ; ARABIC LETTER SHEEN
  (#xD5 #x0635) ; ARABIC LETTER SAD
  (#xD6 #x0636) ; ARABIC LETTER DAD
  (#xD7 #x0637) ; ARABIC LETTER TAH
  (#xD8 #x0638) ; ARABIC LETTER ZAH
  (#xD9 #x0639) ; ARABIC LETTER AIN
  (#xDA #x063A) ; ARABIC LETTER GHAIN
  (#xDB nil)
  (#xDC nil)
  (#xDD nil)
  (#xDE nil)
  (#xDF nil)
  (#xE0 #x0640) ; ARABIC TATWEEL
  (#xE1 #x0641) ; ARABIC LETTER FEH
  (#xE2 #x0642) ; ARABIC LETTER QAF
  (#xE3 #x0643) ; ARABIC LETTER KAF
  (#xE4 #x0644) ; ARABIC LETTER LAM
  (#xE5 #x0645) ; ARABIC LETTER MEEM
  (#xE6 #x0646) ; ARABIC LETTER NOON
  (#xE7 #x0647) ; ARABIC LETTER HEH
  (#xE8 #x0648) ; ARABIC LETTER WAW
  (#xE9 #x0649) ; ARABIC LETTER ALEF MAKSURA
  (#xEA #x064A) ; ARABIC LETTER YEH
  (#xEB #x064B) ; ARABIC FATHATAN
  (#xEC #x064C) ; ARABIC DAMMATAN
  (#xED #x064D) ; ARABIC KASRATAN
  (#xEE #x064E) ; ARABIC FATHA
  (#xEF #x064F) ; ARABIC DAMMA
  (#xF0 #x0650) ; ARABIC KASRA
  (#xF1 #x0651) ; ARABIC SHADDA
  (#xF2 #x0652) ; ARABIC SUKUN
  (#xF3 nil)
  (#xF4 nil)
  (#xF5 nil)
  (#xF6 nil)
  (#xF7 nil)
  (#xF8 nil)
  (#xF9 nil)
  (#xFA nil)
  (#xFB nil)
  (#xFC nil)
  (#xFD nil)
  (#xFE nil)
  (#xFF nil)
)

(define-unibyte-mapping-external-format :iso-8859-7 (:|iso-8859-7|)
  (#xA1 #x02BD) ; MODIFIER LETTER REVERSED COMMA
  (#xA2 #x02BC) ; MODIFIER LETTER APOSTROPHE
  (#xA4 nil)
  (#xA5 nil)
  (#xAA nil)
  (#xAE nil)
  (#xAF #x2015) ; HORIZONTAL BAR
  (#xB4 #x0384) ; GREEK TONOS
  (#xB5 #x0385) ; GREEK DIALYTIKA TONOS
  (#xB6 #x0386) ; GREEK CAPITAL LETTER ALPHA WITH TONOS
  (#xB8 #x0388) ; GREEK CAPITAL LETTER EPSILON WITH TONOS
  (#xB9 #x0389) ; GREEK CAPITAL LETTER ETA WITH TONOS
  (#xBA #x038A) ; GREEK CAPITAL LETTER IOTA WITH TONOS
  (#xBC #x038C) ; GREEK CAPITAL LETTER OMICRON WITH TONOS
  (#xBE #x038E) ; GREEK CAPITAL LETTER UPSILON WITH TONOS
  (#xBF #x038F) ; GREEK CAPITAL LETTER OMEGA WITH TONOS
  (#xC0 #x0390) ; GREEK SMALL LETTER IOTA WITH DIALYTIKA AND TONOS
  (#xC1 #x0391) ; GREEK CAPITAL LETTER ALPHA
  (#xC2 #x0392) ; GREEK CAPITAL LETTER BETA
  (#xC3 #x0393) ; GREEK CAPITAL LETTER GAMMA
  (#xC4 #x0394) ; GREEK CAPITAL LETTER DELTA
  (#xC5 #x0395) ; GREEK CAPITAL LETTER EPSILON
  (#xC6 #x0396) ; GREEK CAPITAL LETTER ZETA
  (#xC7 #x0397) ; GREEK CAPITAL LETTER ETA
  (#xC8 #x0398) ; GREEK CAPITAL LETTER THETA
  (#xC9 #x0399) ; GREEK CAPITAL LETTER IOTA
  (#xCA #x039A) ; GREEK CAPITAL LETTER KAPPA
  (#xCB #x039B) ; GREEK CAPITAL LETTER LAMDA
  (#xCC #x039C) ; GREEK CAPITAL LETTER MU
  (#xCD #x039D) ; GREEK CAPITAL LETTER NU
  (#xCE #x039E) ; GREEK CAPITAL LETTER XI
  (#xCF #x039F) ; GREEK CAPITAL LETTER OMICRON
  (#xD0 #x03A0) ; GREEK CAPITAL LETTER PI
  (#xD1 #x03A1) ; GREEK CAPITAL LETTER RHO
  (#xD2 nil)
  (#xD3 #x03A3) ; GREEK CAPITAL LETTER SIGMA
  (#xD4 #x03A4) ; GREEK CAPITAL LETTER TAU
  (#xD5 #x03A5) ; GREEK CAPITAL LETTER UPSILON
  (#xD6 #x03A6) ; GREEK CAPITAL LETTER PHI
  (#xD7 #x03A7) ; GREEK CAPITAL LETTER CHI
  (#xD8 #x03A8) ; GREEK CAPITAL LETTER PSI
  (#xD9 #x03A9) ; GREEK CAPITAL LETTER OMEGA
  (#xDA #x03AA) ; GREEK CAPITAL LETTER IOTA WITH DIALYTIKA
  (#xDB #x03AB) ; GREEK CAPITAL LETTER UPSILON WITH DIALYTIKA
  (#xDC #x03AC) ; GREEK SMALL LETTER ALPHA WITH TONOS
  (#xDD #x03AD) ; GREEK SMALL LETTER EPSILON WITH TONOS
  (#xDE #x03AE) ; GREEK SMALL LETTER ETA WITH TONOS
  (#xDF #x03AF) ; GREEK SMALL LETTER IOTA WITH TONOS
  (#xE0 #x03B0) ; GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND TONOS
  (#xE1 #x03B1) ; GREEK SMALL LETTER ALPHA
  (#xE2 #x03B2) ; GREEK SMALL LETTER BETA
  (#xE3 #x03B3) ; GREEK SMALL LETTER GAMMA
  (#xE4 #x03B4) ; GREEK SMALL LETTER DELTA
  (#xE5 #x03B5) ; GREEK SMALL LETTER EPSILON
  (#xE6 #x03B6) ; GREEK SMALL LETTER ZETA
  (#xE7 #x03B7) ; GREEK SMALL LETTER ETA
  (#xE8 #x03B8) ; GREEK SMALL LETTER THETA
  (#xE9 #x03B9) ; GREEK SMALL LETTER IOTA
  (#xEA #x03BA) ; GREEK SMALL LETTER KAPPA
  (#xEB #x03BB) ; GREEK SMALL LETTER LAMDA
  (#xEC #x03BC) ; GREEK SMALL LETTER MU
  (#xED #x03BD) ; GREEK SMALL LETTER NU
  (#xEE #x03BE) ; GREEK SMALL LETTER XI
  (#xEF #x03BF) ; GREEK SMALL LETTER OMICRON
  (#xF0 #x03C0) ; GREEK SMALL LETTER PI
  (#xF1 #x03C1) ; GREEK SMALL LETTER RHO
  (#xF2 #x03C2) ; GREEK SMALL LETTER FINAL SIGMA
  (#xF3 #x03C3) ; GREEK SMALL LETTER SIGMA
  (#xF4 #x03C4) ; GREEK SMALL LETTER TAU
  (#xF5 #x03C5) ; GREEK SMALL LETTER UPSILON
  (#xF6 #x03C6) ; GREEK SMALL LETTER PHI
  (#xF7 #x03C7) ; GREEK SMALL LETTER CHI
  (#xF8 #x03C8) ; GREEK SMALL LETTER PSI
  (#xF9 #x03C9) ; GREEK SMALL LETTER OMEGA
  (#xFA #x03CA) ; GREEK SMALL LETTER IOTA WITH DIALYTIKA
  (#xFB #x03CB) ; GREEK SMALL LETTER UPSILON WITH DIALYTIKA
  (#xFC #x03CC) ; GREEK SMALL LETTER OMICRON WITH TONOS
  (#xFD #x03CD) ; GREEK SMALL LETTER UPSILON WITH TONOS
  (#xFE #x03CE) ; GREEK SMALL LETTER OMEGA WITH TONOS
  (#xFF nil)
)

(define-unibyte-mapping-external-format :iso-8859-8 (:|iso-8859-8|)
  (#xA1 nil)
  (#xAA #x00D7) ; MULTIPLICATION SIGN
  (#xAF #x203E) ; OVERLINE
  (#xBA #x00F7) ; DIVISION SIGN
  (#xBF nil)
  (#xC0 nil)
  (#xC1 nil)
  (#xC2 nil)
  (#xC3 nil)
  (#xC4 nil)
  (#xC5 nil)
  (#xC6 nil)
  (#xC7 nil)
  (#xC8 nil)
  (#xC9 nil)
  (#xCA nil)
  (#xCB nil)
  (#xCC nil)
  (#xCD nil)
  (#xCE nil)
  (#xCF nil)
  (#xD0 nil)
  (#xD1 nil)
  (#xD2 nil)
  (#xD3 nil)
  (#xD4 nil)
  (#xD5 nil)
  (#xD6 nil)
  (#xD7 nil)
  (#xD8 nil)
  (#xD9 nil)
  (#xDA nil)
  (#xDB nil)
  (#xDC nil)
  (#xDD nil)
  (#xDE nil)
  (#xDF #x2017) ; DOUBLE LOW LINE
  (#xE0 #x05D0) ; HEBREW LETTER ALEF
  (#xE1 #x05D1) ; HEBREW LETTER BET
  (#xE2 #x05D2) ; HEBREW LETTER GIMEL
  (#xE3 #x05D3) ; HEBREW LETTER DALET
  (#xE4 #x05D4) ; HEBREW LETTER HE
  (#xE5 #x05D5) ; HEBREW LETTER VAV
  (#xE6 #x05D6) ; HEBREW LETTER ZAYIN
  (#xE7 #x05D7) ; HEBREW LETTER HET
  (#xE8 #x05D8) ; HEBREW LETTER TET
  (#xE9 #x05D9) ; HEBREW LETTER YOD
  (#xEA #x05DA) ; HEBREW LETTER FINAL KAF
  (#xEB #x05DB) ; HEBREW LETTER KAF
  (#xEC #x05DC) ; HEBREW LETTER LAMED
  (#xED #x05DD) ; HEBREW LETTER FINAL MEM
  (#xEE #x05DE) ; HEBREW LETTER MEM
  (#xEF #x05DF) ; HEBREW LETTER FINAL NUN
  (#xF0 #x05E0) ; HEBREW LETTER NUN
  (#xF1 #x05E1) ; HEBREW LETTER SAMEKH
  (#xF2 #x05E2) ; HEBREW LETTER AYIN
  (#xF3 #x05E3) ; HEBREW LETTER FINAL PE
  (#xF4 #x05E4) ; HEBREW LETTER PE
  (#xF5 #x05E5) ; HEBREW LETTER FINAL TSADI
  (#xF6 #x05E6) ; HEBREW LETTER TSADI
  (#xF7 #x05E7) ; HEBREW LETTER QOF
  (#xF8 #x05E8) ; HEBREW LETTER RESH
  (#xF9 #x05E9) ; HEBREW LETTER SHIN
  (#xFA #x05EA) ; HEBREW LETTER TAV
  (#xFB nil)
  (#xFC nil)
  (#xFD nil)
  (#xFE nil)
  (#xFF nil)
)

(define-unibyte-mapping-external-format :iso-8859-9
    (:|iso-8859-9| :latin-5 :|latin-5|)
  (#xD0 #x011E) ; LATIN CAPITAL LETTER G WITH BREVE
  (#xDD #x0130) ; LATIN CAPITAL LETTER I WITH DOT ABOVE
  (#xDE #x015E) ; LATIN CAPITAL LETTER S WITH CEDILLA
  (#xF0 #x011F) ; LATIN SMALL LETTER G WITH BREVE
  (#xFD #x0131) ; LATIN SMALL LETTER DOTLESS I
  (#xFE #x015F) ; LATIN SMALL LETTER S WITH CEDILLA
)

(define-unibyte-mapping-external-format :iso-8859-10
    (:|iso-8859-10| :latin-6 :|latin-6|)
  (#xA1 #x0104) ; LATIN CAPITAL LETTER A WITH OGONEK
  (#xA2 #x0112) ; LATIN CAPITAL LETTER E WITH MACRON
  (#xA3 #x0122) ; LATIN CAPITAL LETTER G WITH CEDILLA
  (#xA4 #x012A) ; LATIN CAPITAL LETTER I WITH MACRON
  (#xA5 #x0128) ; LATIN CAPITAL LETTER I WITH TILDE
  (#xA6 #x0136) ; LATIN CAPITAL LETTER K WITH CEDILLA
  (#xA8 #x013B) ; LATIN CAPITAL LETTER L WITH CEDILLA
  (#xA9 #x0110) ; LATIN CAPITAL LETTER D WITH STROKE
  (#xAA #x0160) ; LATIN CAPITAL LETTER S WITH CARON
  (#xAB #x0166) ; LATIN CAPITAL LETTER T WITH STROKE
  (#xAC #x017D) ; LATIN CAPITAL LETTER Z WITH CARON
  (#xAE #x016A) ; LATIN CAPITAL LETTER U WITH MACRON
  (#xAF #x014A) ; LATIN CAPITAL LETTER ENG
  (#xB1 #x0105) ; LATIN SMALL LETTER A WITH OGONEK
  (#xB2 #x0113) ; LATIN SMALL LETTER E WITH MACRON
  (#xB3 #x0123) ; LATIN SMALL LETTER G WITH CEDILLA
  (#xB4 #x012B) ; LATIN SMALL LETTER I WITH MACRON
  (#xB5 #x0129) ; LATIN SMALL LETTER I WITH TILDE
  (#xB6 #x0137) ; LATIN SMALL LETTER K WITH CEDILLA
  (#xB8 #x013C) ; LATIN SMALL LETTER L WITH CEDILLA
  (#xB9 #x0111) ; LATIN SMALL LETTER D WITH STROKE
  (#xBA #x0161) ; LATIN SMALL LETTER S WITH CARON
  (#xBB #x0167) ; LATIN SMALL LETTER T WITH STROKE
  (#xBC #x017E) ; LATIN SMALL LETTER Z WITH CARON
  (#xBD #x2015) ; HORIZONTAL BAR
  (#xBE #x016B) ; LATIN SMALL LETTER U WITH MACRON
  (#xBF #x014B) ; LATIN SMALL LETTER ENG
  (#xC0 #x0100) ; LATIN CAPITAL LETTER A WITH MACRON
  (#xC7 #x012E) ; LATIN CAPITAL LETTER I WITH OGONEK
  (#xC8 #x010C) ; LATIN CAPITAL LETTER C WITH CARON
  (#xCA #x0118) ; LATIN CAPITAL LETTER E WITH OGONEK
  (#xCC #x0116) ; LATIN CAPITAL LETTER E WITH DOT ABOVE
  (#xD1 #x0145) ; LATIN CAPITAL LETTER N WITH CEDILLA
  (#xD2 #x014C) ; LATIN CAPITAL LETTER O WITH MACRON
  (#xD7 #x0168) ; LATIN CAPITAL LETTER U WITH TILDE
  (#xD9 #x0172) ; LATIN CAPITAL LETTER U WITH OGONEK
  (#xE0 #x0101) ; LATIN SMALL LETTER A WITH MACRON
  (#xE7 #x012F) ; LATIN SMALL LETTER I WITH OGONEK
  (#xE8 #x010D) ; LATIN SMALL LETTER C WITH CARON
  (#xEA #x0119) ; LATIN SMALL LETTER E WITH OGONEK
  (#xEC #x0117) ; LATIN SMALL LETTER E WITH DOT ABOVE
  (#xF1 #x0146) ; LATIN SMALL LETTER N WITH CEDILLA
  (#xF2 #x014D) ; LATIN SMALL LETTER O WITH MACRON
  (#xF7 #x0169) ; LATIN SMALL LETTER U WITH TILDE
  (#xF9 #x0173) ; LATIN SMALL LETTER U WITH OGONEK
  (#xFF #x0138) ; LATIN SMALL LETTER KRA
)

(define-unibyte-mapping-external-format :iso-8859-11 (:|iso-8859-11|)
  (#xA1 #x0E01) ; THAI CHARACTER KO KAI
  (#xA2 #x0E02) ; THAI CHARACTER KHO KHAI
  (#xA3 #x0E03) ; THAI CHARACTER KHO KHUAT
  (#xA4 #x0E04) ; THAI CHARACTER KHO KHWAI
  (#xA5 #x0E05) ; THAI CHARACTER KHO KHON
  (#xA6 #x0E06) ; THAI CHARACTER KHO RAKHANG
  (#xA7 #x0E07) ; THAI CHARACTER NGO NGU
  (#xA8 #x0E08) ; THAI CHARACTER CHO CHAN
  (#xA9 #x0E09) ; THAI CHARACTER CHO CHING
  (#xAA #x0E0A) ; THAI CHARACTER CHO CHANG
  (#xAB #x0E0B) ; THAI CHARACTER SO SO
  (#xAC #x0E0C) ; THAI CHARACTER CHO CHOE
  (#xAD #x0E0D) ; THAI CHARACTER YO YING
  (#xAE #x0E0E) ; THAI CHARACTER DO CHADA
  (#xAF #x0E0F) ; THAI CHARACTER TO PATAK
  (#xB0 #x0E10) ; THAI CHARACTER THO THAN
  (#xB1 #x0E11) ; THAI CHARACTER THO NANGMONTHO
  (#xB2 #x0E12) ; THAI CHARACTER THO PHUTHAO
  (#xB3 #x0E13) ; THAI CHARACTER NO NEN
  (#xB4 #x0E14) ; THAI CHARACTER DO DEK
  (#xB5 #x0E15) ; THAI CHARACTER TO TAO
  (#xB6 #x0E16) ; THAI CHARACTER THO THUNG
  (#xB7 #x0E17) ; THAI CHARACTER THO THAHAN
  (#xB8 #x0E18) ; THAI CHARACTER THO THONG
  (#xB9 #x0E19) ; THAI CHARACTER NO NU
  (#xBA #x0E1A) ; THAI CHARACTER BO BAIMAI
  (#xBB #x0E1B) ; THAI CHARACTER PO PLA
  (#xBC #x0E1C) ; THAI CHARACTER PHO PHUNG
  (#xBD #x0E1D) ; THAI CHARACTER FO FA
  (#xBE #x0E1E) ; THAI CHARACTER PHO PHAN
  (#xBF #x0E1F) ; THAI CHARACTER FO FAN
  (#xC0 #x0E20) ; THAI CHARACTER PHO SAMPHAO
  (#xC1 #x0E21) ; THAI CHARACTER MO MA
  (#xC2 #x0E22) ; THAI CHARACTER YO YAK
  (#xC3 #x0E23) ; THAI CHARACTER RO RUA
  (#xC4 #x0E24) ; THAI CHARACTER RU
  (#xC5 #x0E25) ; THAI CHARACTER LO LING
  (#xC6 #x0E26) ; THAI CHARACTER LU
  (#xC7 #x0E27) ; THAI CHARACTER WO WAEN
  (#xC8 #x0E28) ; THAI CHARACTER SO SALA
  (#xC9 #x0E29) ; THAI CHARACTER SO RUSI
  (#xCA #x0E2A) ; THAI CHARACTER SO SUA
  (#xCB #x0E2B) ; THAI CHARACTER HO HIP
  (#xCC #x0E2C) ; THAI CHARACTER LO CHULA
  (#xCD #x0E2D) ; THAI CHARACTER O ANG
  (#xCE #x0E2E) ; THAI CHARACTER HO NOKHUK
  (#xCF #x0E2F) ; THAI CHARACTER PAIYANNOI
  (#xD0 #x0E30) ; THAI CHARACTER SARA A
  (#xD1 #x0E31) ; THAI CHARACTER MAI HAN-AKAT
  (#xD2 #x0E32) ; THAI CHARACTER SARA AA
  (#xD3 #x0E33) ; THAI CHARACTER SARA AM
  (#xD4 #x0E34) ; THAI CHARACTER SARA I
  (#xD5 #x0E35) ; THAI CHARACTER SARA II
  (#xD6 #x0E36) ; THAI CHARACTER SARA UE
  (#xD7 #x0E37) ; THAI CHARACTER SARA UEE
  (#xD8 #x0E38) ; THAI CHARACTER SARA U
  (#xD9 #x0E39) ; THAI CHARACTER SARA UU
  (#xDA #x0E3A) ; THAI CHARACTER PHINTHU
  (#xDB nil)
  (#xDC nil)
  (#xDD nil)
  (#xDE nil)
  (#xDF #x0E3F) ; THAI CURRENCY SYMBOL BAHT
  (#xE0 #x0E40) ; THAI CHARACTER SARA E
  (#xE1 #x0E41) ; THAI CHARACTER SARA AE
  (#xE2 #x0E42) ; THAI CHARACTER SARA O
  (#xE3 #x0E43) ; THAI CHARACTER SARA AI MAIMUAN
  (#xE4 #x0E44) ; THAI CHARACTER SARA AI MAIMALAI
  (#xE5 #x0E45) ; THAI CHARACTER LAKKHANGYAO
  (#xE6 #x0E46) ; THAI CHARACTER MAIYAMOK
  (#xE7 #x0E47) ; THAI CHARACTER MAITAIKHU
  (#xE8 #x0E48) ; THAI CHARACTER MAI EK
  (#xE9 #x0E49) ; THAI CHARACTER MAI THO
  (#xEA #x0E4A) ; THAI CHARACTER MAI TRI
  (#xEB #x0E4B) ; THAI CHARACTER MAI CHATTAWA
  (#xEC #x0E4C) ; THAI CHARACTER THANTHAKHAT
  (#xED #x0E4D) ; THAI CHARACTER NIKHAHIT
  (#xEE #x0E4E) ; THAI CHARACTER YAMAKKAN
  (#xEF #x0E4F) ; THAI CHARACTER FONGMAN
  (#xF0 #x0E50) ; THAI DIGIT ZERO
  (#xF1 #x0E51) ; THAI DIGIT ONE
  (#xF2 #x0E52) ; THAI DIGIT TWO
  (#xF3 #x0E53) ; THAI DIGIT THREE
  (#xF4 #x0E54) ; THAI DIGIT FOUR
  (#xF5 #x0E55) ; THAI DIGIT FIVE
  (#xF6 #x0E56) ; THAI DIGIT SIX
  (#xF7 #x0E57) ; THAI DIGIT SEVEN
  (#xF8 #x0E58) ; THAI DIGIT EIGHT
  (#xF9 #x0E59) ; THAI DIGIT NINE
  (#xFA #x0E5A) ; THAI CHARACTER ANGKHANKHU
  (#xFB #x0E5B) ; THAI CHARACTER KHOMUT
  (#xFC nil)
  (#xFD nil)
  (#xFE nil)
  (#xFF nil)
)

(define-unibyte-mapping-external-format :iso-8859-13
    (:|iso-8859-13| :latin-7 :|latin-7|)
  (#xA1 #x201D) ; RIGHT DOUBLE QUOTATION MARK
  (#xA5 #x201E) ; DOUBLE LOW-9 QUOTATION MARK
  (#xA8 #x00D8) ; LATIN CAPITAL LETTER O WITH STROKE
  (#xAA #x0156) ; LATIN CAPITAL LETTER R WITH CEDILLA
  (#xAF #x00C6) ; LATIN CAPITAL LETTER AE
  (#xB4 #x201C) ; LEFT DOUBLE QUOTATION MARK
  (#xB8 #x00F8) ; LATIN SMALL LETTER O WITH STROKE
  (#xBA #x0157) ; LATIN SMALL LETTER R WITH CEDILLA
  (#xBF #x00E6) ; LATIN SMALL LETTER AE
  (#xC0 #x0104) ; LATIN CAPITAL LETTER A WITH OGONEK
  (#xC1 #x012E) ; LATIN CAPITAL LETTER I WITH OGONEK
  (#xC2 #x0100) ; LATIN CAPITAL LETTER A WITH MACRON
  (#xC3 #x0106) ; LATIN CAPITAL LETTER C WITH ACUTE
  (#xC6 #x0118) ; LATIN CAPITAL LETTER E WITH OGONEK
  (#xC7 #x0112) ; LATIN CAPITAL LETTER E WITH MACRON
  (#xC8 #x010C) ; LATIN CAPITAL LETTER C WITH CARON
  (#xCA #x0179) ; LATIN CAPITAL LETTER Z WITH ACUTE
  (#xCB #x0116) ; LATIN CAPITAL LETTER E WITH DOT ABOVE
  (#xCC #x0122) ; LATIN CAPITAL LETTER G WITH CEDILLA
  (#xCD #x0136) ; LATIN CAPITAL LETTER K WITH CEDILLA
  (#xCE #x012A) ; LATIN CAPITAL LETTER I WITH MACRON
  (#xCF #x013B) ; LATIN CAPITAL LETTER L WITH CEDILLA
  (#xD0 #x0160) ; LATIN CAPITAL LETTER S WITH CARON
  (#xD1 #x0143) ; LATIN CAPITAL LETTER N WITH ACUTE
  (#xD2 #x0145) ; LATIN CAPITAL LETTER N WITH CEDILLA
  (#xD4 #x014C) ; LATIN CAPITAL LETTER O WITH MACRON
  (#xD8 #x0172) ; LATIN CAPITAL LETTER U WITH OGONEK
  (#xD9 #x0141) ; LATIN CAPITAL LETTER L WITH STROKE
  (#xDA #x015A) ; LATIN CAPITAL LETTER S WITH ACUTE
  (#xDB #x016A) ; LATIN CAPITAL LETTER U WITH MACRON
  (#xDD #x017B) ; LATIN CAPITAL LETTER Z WITH DOT ABOVE
  (#xDE #x017D) ; LATIN CAPITAL LETTER Z WITH CARON
  (#xE0 #x0105) ; LATIN SMALL LETTER A WITH OGONEK
  (#xE1 #x012F) ; LATIN SMALL LETTER I WITH OGONEK
  (#xE2 #x0101) ; LATIN SMALL LETTER A WITH MACRON
  (#xE3 #x0107) ; LATIN SMALL LETTER C WITH ACUTE
  (#xE6 #x0119) ; LATIN SMALL LETTER E WITH OGONEK
  (#xE7 #x0113) ; LATIN SMALL LETTER E WITH MACRON
  (#xE8 #x010D) ; LATIN SMALL LETTER C WITH CARON
  (#xEA #x017A) ; LATIN SMALL LETTER Z WITH ACUTE
  (#xEB #x0117) ; LATIN SMALL LETTER E WITH DOT ABOVE
  (#xEC #x0123) ; LATIN SMALL LETTER G WITH CEDILLA
  (#xED #x0137) ; LATIN SMALL LETTER K WITH CEDILLA
  (#xEE #x012B) ; LATIN SMALL LETTER I WITH MACRON
  (#xEF #x013C) ; LATIN SMALL LETTER L WITH CEDILLA
  (#xF0 #x0161) ; LATIN SMALL LETTER S WITH CARON
  (#xF1 #x0144) ; LATIN SMALL LETTER N WITH ACUTE
  (#xF2 #x0146) ; LATIN SMALL LETTER N WITH CEDILLA
  (#xF4 #x014D) ; LATIN SMALL LETTER O WITH MACRON
  (#xF8 #x0173) ; LATIN SMALL LETTER U WITH OGONEK
  (#xF9 #x0142) ; LATIN SMALL LETTER L WITH STROKE
  (#xFA #x015B) ; LATIN SMALL LETTER S WITH ACUTE
  (#xFB #x016B) ; LATIN SMALL LETTER U WITH MACRON
  (#xFD #x017C) ; LATIN SMALL LETTER Z WITH DOT ABOVE
  (#xFE #x017E) ; LATIN SMALL LETTER Z WITH CARON
  (#xFF #x2019) ; RIGHT SINGLE QUOTATION MARK
)

(define-unibyte-mapping-external-format :iso-8859-14
    (:|iso-8859-14| :latin-8 :|latin-8|)
  (#xA1 #x1E02) ; LATIN CAPITAL LETTER B WITH DOT ABOVE
  (#xA2 #x1E03) ; LATIN SMALL LETTER B WITH DOT ABOVE
  (#xA4 #x010A) ; LATIN CAPITAL LETTER C WITH DOT ABOVE
  (#xA5 #x010B) ; LATIN SMALL LETTER C WITH DOT ABOVE
  (#xA6 #x1E0A) ; LATIN CAPITAL LETTER D WITH DOT ABOVE
  (#xA8 #x1E80) ; LATIN CAPITAL LETTER W WITH GRAVE
  (#xAA #x1E82) ; LATIN CAPITAL LETTER W WITH ACUTE
  (#xAB #x1E0B) ; LATIN SMALL LETTER D WITH DOT ABOVE
  (#xAC #x1EF2) ; LATIN CAPITAL LETTER Y WITH GRAVE
  (#xAF #x0178) ; LATIN CAPITAL LETTER Y WITH DIAERESIS
  (#xB0 #x1E1E) ; LATIN CAPITAL LETTER F WITH DOT ABOVE
  (#xB1 #x1E1F) ; LATIN SMALL LETTER F WITH DOT ABOVE
  (#xB2 #x0120) ; LATIN CAPITAL LETTER G WITH DOT ABOVE
  (#xB3 #x0121) ; LATIN SMALL LETTER G WITH DOT ABOVE
  (#xB4 #x1E40) ; LATIN CAPITAL LETTER M WITH DOT ABOVE
  (#xB5 #x1E41) ; LATIN SMALL LETTER M WITH DOT ABOVE
  (#xB7 #x1E56) ; LATIN CAPITAL LETTER P WITH DOT ABOVE
  (#xB8 #x1E81) ; LATIN SMALL LETTER W WITH GRAVE
  (#xB9 #x1E57) ; LATIN SMALL LETTER P WITH DOT ABOVE
  (#xBA #x1E83) ; LATIN SMALL LETTER W WITH ACUTE
  (#xBB #x1E60) ; LATIN CAPITAL LETTER S WITH DOT ABOVE
  (#xBC #x1EF3) ; LATIN SMALL LETTER Y WITH GRAVE
  (#xBD #x1E84) ; LATIN CAPITAL LETTER W WITH DIAERESIS
  (#xBE #x1E85) ; LATIN SMALL LETTER W WITH DIAERESIS
  (#xBF #x1E61) ; LATIN SMALL LETTER S WITH DOT ABOVE
  (#xD0 #x0174) ; LATIN CAPITAL LETTER W WITH CIRCUMFLEX
  (#xD7 #x1E6A) ; LATIN CAPITAL LETTER T WITH DOT ABOVE
  (#xDE #x0176) ; LATIN CAPITAL LETTER Y WITH CIRCUMFLEX
  (#xF0 #x0175) ; LATIN SMALL LETTER W WITH CIRCUMFLEX
  (#xF7 #x1E6B) ; LATIN SMALL LETTER T WITH DOT ABOVE
  (#xFE #x0177) ; LATIN SMALL LETTER Y WITH CIRCUMFLEX
)

;;; The names for latin9 are different due to a historical accident.
(define-unibyte-mapping-external-format :latin-9
    (:latin9 :iso-8859-15 :iso8859-15)
  (#xA4 #x20AC)
  (#xA6 #x0160)
  (#xA8 #x0161)
  (#xB4 #x017D)
  (#xB8 #x017E)
  (#xBC #x0152)
  (#xBD #x0153)
  (#xBE #x0178)
)
