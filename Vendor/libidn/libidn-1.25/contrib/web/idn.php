<?php

$charset = $_REQUEST["charset"];
$lastcharset = $_REQUEST["lastcharset"];
$mode = $_REQUEST["mode"];
$data = $_REQUEST["data"];
$profile = $_REQUEST["profile"];
$allowunassigned = $_REQUEST["allowunassigned"];
$usestd3asciirules = $_REQUEST["usestd3asciirules"];
$debug = $_REQUEST["debug"];

if (!$charset) {
	$data = "räksmörgås.josefßon.org";
	$charset = "UTF-8";
}

header("Content-Type: text/html; charset=$charset");
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=<?php print $charset ?>">
    <title>Try GNU Libidn</title>
  </head>

  <body>

    <h1>Try GNU Libidn</h1>

    <p>This page allows you to try the string preparation, punycode
    encode/decode and ToASCII/ToUnicode operations of <a
    href="http://www.gnu.org/software/libidn/">GNU Libidn</a>.  If you
    encounter a problem with this page, write a (detailed!) report to
    <A HREF="mailto:bug-libidn@gnu.org">bug-libidn@gnu.org</A>.

    <p>If you are interested in commercial support or enhancement of
    Libidn, you can <a href="mailto:simon@josefsson.org">contact
    me</a>.

<?php if (!$lastcharset && !$mode) { ?>

    <p>Free shrimp sandwiches are <a
    href="http://xn--rksmrgs-5wao1o.josefsson.org/">served over
    here</a> (or <a href="http://räksmörgås.josefsson.org/">here</a>
    if you want the experimental flavour).

    <p>This page ignores any Accept-Charset headers sent by your
    browser.  Instead, the Unicode repertoire encoded as UTF-8 is
    used.  If you are using software that cannot handle this, you must
    select another MIME charset below.  BIG5, ISO-2022-JP-2,
    ISO-8859-1, and KOI-8 are popular choices.  I am sorry for the
    inconvenience.

<?php } ?>

    <hr>
    <h2>Input</h2>
    <form>

      <p>The following string must only contain characters that your
      browser is able to represent in <?php print $charset; ?> when
      submitting this form.  If you wish to use another charset you
      must select it below, submit the form and wait for a new page to
      load, and then enter your string.<br>

      <input type=text name=data size=40 value="<?php print $data ?>"><br>

      <input type=radio name=mode value=stringprep <?php if ($mode == "stringprep") { print "checked"; } ?>>Prepare string using profile:

      <select name=profile>
	<option <?php if ($profile == "Nameprep" || !$profile) { print "selected"; } ?>>Nameprep
	<option <?php if ($profile == "KRBprep") { print "selected"; } ?>>KRBprep
	<option <?php if ($profile == "Nodeprep") { print "selected"; } ?>>Nodeprep
	<option <?php if ($profile == "Resourceprep") { print "selected"; } ?>>Resourceprep
	<option <?php if ($profile == "plain") { print "selected"; } ?>>plain
	<option <?php if ($profile == "trace") { print "selected"; } ?>>trace
	<option <?php if ($profile == "SASLprep") { print "selected"; } ?>>SASLprep
	<option <?php if ($profile == "ISCSIprep") { print "selected"; } ?>>ISCSIprep
      </select><br>

      <input type=radio name=mode value=punyencode <?php if ($mode == "punyencode") { print "checked"; } ?>>Punycode encode<br>
      <input type=radio name=mode value=punydecode <?php if ($mode == "punydecode") { print "checked"; } ?>> Punycode decode<br>

      <input type=radio name=mode value=toascii <?php if ($mode == "toascii" || !$mode) { print "checked"; } ?>>IDNA ToASCII<br>
      <input type=radio name=mode value=tounicode <?php if ($mode == "tounicode") { print "checked"; } ?>>IDNA ToUnicode<br>

      <input type=checkbox name=allowunassigned <?php if ($allowunassigned) { print "checked"; } ?>>Allow Unassigned<br>
      <input type=checkbox name=usestd3asciirules <?php if ($usestd3asciirules) { print "checked"; } ?>>UseSTD3ASCIIRules<br>
      <input type=checkbox name=debug <?php if ($debug) { print "checked"; } ?>>Debug<br>

      Change MIME charset of page to: <select name=charset>

<option <?php if ($charset == "ASCII") { print "selected"; } ?>>ASCII
<option <?php if ($charset == "ASMO_449") { print "selected"; } ?>>ASMO_449
<option <?php if ($charset == "BIG5") { print "selected"; } ?>>BIG5
<option <?php if ($charset == "BIG5HKSCS") { print "selected"; } ?>>BIG5HKSCS
<option <?php if ($charset == "BS_4730") { print "selected"; } ?>>BS_4730
<option <?php if ($charset == "CP10007") { print "selected"; } ?>>CP10007
<option <?php if ($charset == "CP1250") { print "selected"; } ?>>CP1250
<option <?php if ($charset == "CP1251") { print "selected"; } ?>>CP1251
<option <?php if ($charset == "CP1252") { print "selected"; } ?>>CP1252
<option <?php if ($charset == "CP1253") { print "selected"; } ?>>CP1253
<option <?php if ($charset == "CP1254") { print "selected"; } ?>>CP1254
<option <?php if ($charset == "CP1255") { print "selected"; } ?>>CP1255
<option <?php if ($charset == "CP1256") { print "selected"; } ?>>CP1256
<option <?php if ($charset == "CP1257") { print "selected"; } ?>>CP1257
<option <?php if ($charset == "CP1258") { print "selected"; } ?>>CP1258
<option <?php if ($charset == "CP737") { print "selected"; } ?>>CP737
<option <?php if ($charset == "CP775") { print "selected"; } ?>>CP775
<option <?php if ($charset == "CSA_Z243.4-1985-1") { print "selected"; } ?>>CSA_Z243.4-1985-1
<option <?php if ($charset == "CSA_Z243.4-1985-2") { print "selected"; } ?>>CSA_Z243.4-1985-2
<option <?php if ($charset == "CSN_369103") { print "selected"; } ?>>CSN_369103
<option <?php if ($charset == "CWI") { print "selected"; } ?>>CWI
<option <?php if ($charset == "DEC-MCS") { print "selected"; } ?>>DEC-MCS
<option <?php if ($charset == "DIN_66003") { print "selected"; } ?>>DIN_66003
<option <?php if ($charset == "DS_2089") { print "selected"; } ?>>DS_2089
<option <?php if ($charset == "ECMA-CYRILLIC") { print "selected"; } ?>>ECMA-CYRILLIC
<option <?php if ($charset == "ES") { print "selected"; } ?>>ES
<option <?php if ($charset == "ES2") { print "selected"; } ?>>ES2
<option <?php if ($charset == "EUC-CN") { print "selected"; } ?>>EUC-CN
<option <?php if ($charset == "EUC-JP") { print "selected"; } ?>>EUC-JP
<option <?php if ($charset == "EUC-KR") { print "selected"; } ?>>EUC-KR
<option <?php if ($charset == "EUC-TW") { print "selected"; } ?>>EUC-TW
<option <?php if ($charset == "GB18030") { print "selected"; } ?>>GB18030
<option <?php if ($charset == "GB_1988-80") { print "selected"; } ?>>GB_1988-80
<option <?php if ($charset == "GBK") { print "selected"; } ?>>GBK
<option <?php if ($charset == "GEORGIAN-ACADEMY") { print "selected"; } ?>>GEORGIAN-ACADEMY
<option <?php if ($charset == "GEORGIAN-PS") { print "selected"; } ?>>GEORGIAN-PS
<option <?php if ($charset == "GOST_19768-74") { print "selected"; } ?>>GOST_19768-74
<option <?php if ($charset == "GREEK7") { print "selected"; } ?>>GREEK7
<option <?php if ($charset == "GREEK7-OLD") { print "selected"; } ?>>GREEK7-OLD
<option <?php if ($charset == "GREEK-CCITT") { print "selected"; } ?>>GREEK-CCITT
<option <?php if ($charset == "HP-ROMAN8") { print "selected"; } ?>>HP-ROMAN8
<option <?php if ($charset == "IBM037") { print "selected"; } ?>>IBM037
<option <?php if ($charset == "IBM038") { print "selected"; } ?>>IBM038
<option <?php if ($charset == "IBM1004") { print "selected"; } ?>>IBM1004
<option <?php if ($charset == "IBM1026") { print "selected"; } ?>>IBM1026
<option <?php if ($charset == "IBM1046") { print "selected"; } ?>>IBM1046
<option <?php if ($charset == "IBM1047") { print "selected"; } ?>>IBM1047
<option <?php if ($charset == "IBM1124") { print "selected"; } ?>>IBM1124
<option <?php if ($charset == "IBM1129") { print "selected"; } ?>>IBM1129
<option <?php if ($charset == "IBM1160") { print "selected"; } ?>>IBM1160
<option <?php if ($charset == "IBM1161") { print "selected"; } ?>>IBM1161
<option <?php if ($charset == "IBM256") { print "selected"; } ?>>IBM256
<option <?php if ($charset == "IBM273") { print "selected"; } ?>>IBM273
<option <?php if ($charset == "IBM274") { print "selected"; } ?>>IBM274
<option <?php if ($charset == "IBM275") { print "selected"; } ?>>IBM275
<option <?php if ($charset == "IBM277") { print "selected"; } ?>>IBM277
<option <?php if ($charset == "IBM278") { print "selected"; } ?>>IBM278
<option <?php if ($charset == "IBM280") { print "selected"; } ?>>IBM280
<option <?php if ($charset == "IBM281") { print "selected"; } ?>>IBM281
<option <?php if ($charset == "IBM284") { print "selected"; } ?>>IBM284
<option <?php if ($charset == "IBM285") { print "selected"; } ?>>IBM285
<option <?php if ($charset == "IBM290") { print "selected"; } ?>>IBM290
<option <?php if ($charset == "IBM297") { print "selected"; } ?>>IBM297
<option <?php if ($charset == "IBM420") { print "selected"; } ?>>IBM420
<option <?php if ($charset == "IBM423") { print "selected"; } ?>>IBM423
<option <?php if ($charset == "IBM424") { print "selected"; } ?>>IBM424
<option <?php if ($charset == "IBM437") { print "selected"; } ?>>IBM437
<option <?php if ($charset == "IBM500") { print "selected"; } ?>>IBM500
<option <?php if ($charset == "IBM850") { print "selected"; } ?>>IBM850
<option <?php if ($charset == "IBM851") { print "selected"; } ?>>IBM851
<option <?php if ($charset == "IBM852") { print "selected"; } ?>>IBM852
<option <?php if ($charset == "IBM855") { print "selected"; } ?>>IBM855
<option <?php if ($charset == "IBM856") { print "selected"; } ?>>IBM856
<option <?php if ($charset == "IBM857") { print "selected"; } ?>>IBM857
<option <?php if ($charset == "IBM860") { print "selected"; } ?>>IBM860
<option <?php if ($charset == "IBM861") { print "selected"; } ?>>IBM861
<option <?php if ($charset == "IBM862") { print "selected"; } ?>>IBM862
<option <?php if ($charset == "IBM863") { print "selected"; } ?>>IBM863
<option <?php if ($charset == "IBM864") { print "selected"; } ?>>IBM864
<option <?php if ($charset == "IBM865") { print "selected"; } ?>>IBM865
<option <?php if ($charset == "IBM866") { print "selected"; } ?>>IBM866
<option <?php if ($charset == "IBM868") { print "selected"; } ?>>IBM868
<option <?php if ($charset == "IBM869") { print "selected"; } ?>>IBM869
<option <?php if ($charset == "IBM870") { print "selected"; } ?>>IBM870
<option <?php if ($charset == "IBM871") { print "selected"; } ?>>IBM871
<option <?php if ($charset == "IBM874") { print "selected"; } ?>>IBM874
<option <?php if ($charset == "IBM875") { print "selected"; } ?>>IBM875
<option <?php if ($charset == "IBM880") { print "selected"; } ?>>IBM880
<option <?php if ($charset == "IBM891") { print "selected"; } ?>>IBM891
<option <?php if ($charset == "IBM903") { print "selected"; } ?>>IBM903
<option <?php if ($charset == "IBM904") { print "selected"; } ?>>IBM904
<option <?php if ($charset == "IBM905") { print "selected"; } ?>>IBM905
<option <?php if ($charset == "IBM918") { print "selected"; } ?>>IBM918
<option <?php if ($charset == "IBM922") { print "selected"; } ?>>IBM922
<option <?php if ($charset == "IBM930") { print "selected"; } ?>>IBM930
<option <?php if ($charset == "IBM932") { print "selected"; } ?>>IBM932
<option <?php if ($charset == "IBM933") { print "selected"; } ?>>IBM933
<option <?php if ($charset == "IBM935") { print "selected"; } ?>>IBM935
<option <?php if ($charset == "IBM937") { print "selected"; } ?>>IBM937
<option <?php if ($charset == "IBM939") { print "selected"; } ?>>IBM939
<option <?php if ($charset == "IBM943") { print "selected"; } ?>>IBM943
<option <?php if ($charset == "IEC_P27-1") { print "selected"; } ?>>IEC_P27-1
<option <?php if ($charset == "INIS") { print "selected"; } ?>>INIS
<option <?php if ($charset == "INIS-8") { print "selected"; } ?>>INIS-8
<option <?php if ($charset == "INIS-CYRILLIC") { print "selected"; } ?>>INIS-CYRILLIC
<option <?php if ($charset == "ISIRI-3342") { print "selected"; } ?>>ISIRI-3342
<option <?php if ($charset == "ISO_10367-BOX") { print "selected"; } ?>>ISO_10367-BOX
<option <?php if ($charset == "ISO-2022-CN") { print "selected"; } ?>>ISO-2022-CN
<option <?php if ($charset == "ISO-2022-CN-EXT") { print "selected"; } ?>>ISO-2022-CN-EXT
<option <?php if ($charset == "ISO-2022-JP") { print "selected"; } ?>>ISO-2022-JP
<option <?php if ($charset == "ISO-2022-JP-2") { print "selected"; } ?>>ISO-2022-JP-2
<option <?php if ($charset == "ISO-2022-KR") { print "selected"; } ?>>ISO-2022-KR
<option <?php if ($charset == "ISO_2033") { print "selected"; } ?>>ISO_2033
<option <?php if ($charset == "ISO_5427") { print "selected"; } ?>>ISO_5427
<option <?php if ($charset == "ISO_5427-EXT") { print "selected"; } ?>>ISO_5427-EXT
<option <?php if ($charset == "ISO_5428") { print "selected"; } ?>>ISO_5428
<option <?php if ($charset == "ISO_6937") { print "selected"; } ?>>ISO_6937
<option <?php if ($charset == "ISO_6937-2") { print "selected"; } ?>>ISO_6937-2
<option <?php if ($charset == "ISO-8859-1") { print "selected"; } ?>>ISO-8859-1
<option <?php if ($charset == "ISO-8859-10") { print "selected"; } ?>>ISO-8859-10
<option <?php if ($charset == "ISO-8859-11") { print "selected"; } ?>>ISO-8859-11
<option <?php if ($charset == "ISO-8859-13") { print "selected"; } ?>>ISO-8859-13
<option <?php if ($charset == "ISO-8859-14") { print "selected"; } ?>>ISO-8859-14
<option <?php if ($charset == "ISO-8859-15") { print "selected"; } ?>>ISO-8859-15
<option <?php if ($charset == "ISO-8859-16") { print "selected"; } ?>>ISO-8859-16
<option <?php if ($charset == "ISO-8859-2") { print "selected"; } ?>>ISO-8859-2
<option <?php if ($charset == "ISO-8859-3") { print "selected"; } ?>>ISO-8859-3
<option <?php if ($charset == "ISO-8859-4") { print "selected"; } ?>>ISO-8859-4
<option <?php if ($charset == "ISO-8859-5") { print "selected"; } ?>>ISO-8859-5
<option <?php if ($charset == "ISO-8859-6") { print "selected"; } ?>>ISO-8859-6
<option <?php if ($charset == "ISO-8859-7") { print "selected"; } ?>>ISO-8859-7
<option <?php if ($charset == "ISO-8859-8") { print "selected"; } ?>>ISO-8859-8
<option <?php if ($charset == "ISO-8859-9") { print "selected"; } ?>>ISO-8859-9
<option <?php if ($charset == "ISO-IR-197") { print "selected"; } ?>>ISO-IR-197
<option <?php if ($charset == "ISO-IR-209") { print "selected"; } ?>>ISO-IR-209
<option <?php if ($charset == "IT") { print "selected"; } ?>>IT
<option <?php if ($charset == "JIS_C6220-1969-RO") { print "selected"; } ?>>JIS_C6220-1969-RO
<option <?php if ($charset == "JIS_C6229-1984-B") { print "selected"; } ?>>JIS_C6229-1984-B
<option <?php if ($charset == "JOHAB") { print "selected"; } ?>>JOHAB
<option <?php if ($charset == "JUS_I.B1.002") { print "selected"; } ?>>JUS_I.B1.002
<option <?php if ($charset == "KOI-8") { print "selected"; } ?>>KOI-8
<option <?php if ($charset == "KOI8-R") { print "selected"; } ?>>KOI8-R
<option <?php if ($charset == "KOI8-T") { print "selected"; } ?>>KOI8-T
<option <?php if ($charset == "KOI8-U") { print "selected"; } ?>>KOI8-U
<option <?php if ($charset == "KSC5636") { print "selected"; } ?>>KSC5636
<option <?php if ($charset == "LATIN-GREEK") { print "selected"; } ?>>LATIN-GREEK
<option <?php if ($charset == "LATIN-GREEK-1") { print "selected"; } ?>>LATIN-GREEK-1
<option <?php if ($charset == "MACINTOSH") { print "selected"; } ?>>MACINTOSH
<option <?php if ($charset == "MAC-IS") { print "selected"; } ?>>MAC-IS
<option <?php if ($charset == "MAC-SAMI") { print "selected"; } ?>>MAC-SAMI
<option <?php if ($charset == "MAC-UK") { print "selected"; } ?>>MAC-UK
<option <?php if ($charset == "MSZ_7795.3") { print "selected"; } ?>>MSZ_7795.3
<option <?php if ($charset == "NATS-DANO") { print "selected"; } ?>>NATS-DANO
<option <?php if ($charset == "NATS-SEFI") { print "selected"; } ?>>NATS-SEFI
<option <?php if ($charset == "NC_NC00-10") { print "selected"; } ?>>NC_NC00-10
<option <?php if ($charset == "NF_Z_62-010") { print "selected"; } ?>>NF_Z_62-010
<option <?php if ($charset == "NF_Z_62-010_1973") { print "selected"; } ?>>NF_Z_62-010_1973
<option <?php if ($charset == "NS_4551-1") { print "selected"; } ?>>NS_4551-1
<option <?php if ($charset == "NS_4551-2") { print "selected"; } ?>>NS_4551-2
<option <?php if ($charset == "PT") { print "selected"; } ?>>PT
<option <?php if ($charset == "PT2") { print "selected"; } ?>>PT2
<option <?php if ($charset == "SEN_850200_B") { print "selected"; } ?>>SEN_850200_B
<option <?php if ($charset == "SEN_850200_C") { print "selected"; } ?>>SEN_850200_C
<option <?php if ($charset == "SJIS") { print "selected"; } ?>>SJIS
<option <?php if ($charset == "T.61-8BIT") { print "selected"; } ?>>T.61-8BIT
<option <?php if ($charset == "TIS-620") { print "selected"; } ?>>TIS-620
<option <?php if ($charset == "UHC") { print "selected"; } ?>>UHC
<option <?php if ($charset == "UTF-8") { print "selected"; } ?>>UTF-8
<option <?php if ($charset == "UTF-7") { print "selected"; } ?>>UTF-7
<option <?php if ($charset == "VISCII") { print "selected"; } ?>>VISCII
<option <?php if ($charset == "WIN-SAMI-2") { print "selected"; } ?>>WIN-SAMI-2

	</select><br>

      <input type=hidden name="lastcharset" value="<?php print $charset; ?>">
      <input type=submit><br>
    </form>

    <hr>
    <h2>Output</h2>

    <pre>
<?php
   putenv("CHARSET=" . escapeshellarg($charset));
   $cmd = "idn" . ($debug ? " --debug" : "") . ($allowunassigned ? " --allow-unassigned" : "") . ($usestd3asciirules ? " --usestd3asciirules" : "") . ($mode == "stringprep" ? " --stringprep" : "") . ($mode == "stringprep" ? " --profile " . escapeshellarg($profile) : "") . ($mode == "punydecode" ? " --punycode-decode" : "") . ($mode == "punyencode" ? " --punycode-encode" : "") . ($mode == "toascii" || !$mode ? " --idna-to-ascii" : "") . ($mode == "tounicode" ? " --idna-to-unicode" : "") . " " . escapeshellarg($data) . " 2>&1";
   $h = popen($cmd, "r");
   while($s = fgets($h, 1024)) { $out .= $s; };
   pclose($h);
   print "$ CHARSET=" .  escapeshellarg($charset) . " $cmd\n";
   print $out;
   print "$ \n";
?>
</pre>
    <hr>
    <h2>Examples</h2>

    <ul>
	<li><a href="http://josefsson.org/idn.php?data=r%E4ksm%F6rg%E5s.josefsson.org&amp;mode=toascii&amp;charset=ISO-8859-1">ISO-8859-1 example</a>
	<li><a href="http://josefsson.org/idn.php?data=r%84ksm%94rg%86s.josefsson.org&amp;mode=toascii&amp;charset=IBM850">IBM850 (aka codepage 850) example (same as previous)</a>
	<li><a href="http://josefsson.org/idn.php?data=r%C8aksm%C8org%CAas.josefsson.org&amp;mode=toascii&amp;charset=T.61-8BIT">T.61-8BIT example (same as previous)</a>
	<li><a href="http://josefsson.org/idn.php?data=%E2%82%ACcu&amp;mode=toascii&amp;charset=UTF-8">UTF-8 Euro example</a>
	<li><a href="http://josefsson.org/idn.php?data=%A4cu&amp;mode=toascii&amp;charset=ISO-8859-15">ISO-8859-15 Euro example (same as previous)</a>
	<li><a href="http://josefsson.org/idn.php?data=%B0%C2%BC%BC%C6%E0%C8%FE%B7%C3-with-SUPER-MONKEYS&amp;mode=toascii&amp;charset=EUC-JP">EUC-JP example</a>
	<li><a href="http://josefsson.org/idn.php?data=%B9%CC%BC%FA&amp;mode=toascii&amp;charset=EUC-KR">EUC-KR example</a>
	<li><a href="http://josefsson.org/idn.php?data=%D9%84%D9%8A%D9%87%D9%85%D8%A7%D8%A8%D8%AA%D9%83%D9%84%D9%85%D9%88%D8%B4%D8%B9%D8%B1%D8%A8%D9%8A%D8%9F&amp;mode=toascii&amp;charset=UTF-8">UTF-8 Arabic (Egyptian)</a>
	<li><a href="http://josefsson.org/idn.php?data=%E4%BB%96%E4%BB%AC%E4%B8%BA%E4%BB%80%E4%B9%88%E4%B8%8D%E8%AF%B4%E4%B8%AD%E6%96%87&amp;mode=toascii&amp;charset=UTF-8">UTF-8 Simplified Chinese</a>
	<li><a href="http://josefsson.org/idn.php?data=%CB%FB%C3%C7%CE%AA%CA%B2%C3%B4%B2%BB%CB%B5%D6%D0%CE%C4&amp;mode=toascii&amp;charset=GB18030">GB18030 Simplified Chinese (same as previous)</a>
	<li><a href="http://josefsson.org/idn.php?data=%D7%9C%D7%9E%D7%94%D7%94%D7%9D%D7%A4%D7%A9%D7%95%D7%98%D7%9C%D7%90%D7%9E%D7%93%D7%91%D7%A8%D7%99%D7%9D%D7%A2%D7%91%D7%A8%D7%99%D7%AA&amp;mode=toascii&amp;charset=UTF-8">UTF-8 Hebrew</a>
	<li><a href="http://josefsson.org/idn.php?data=%EC%EE%E4%E4%ED%F4%F9%E5%E8%EC%E0%EE%E3%E1%F8%E9%ED%F2%E1%F8%E9%FA&amp;mode=toascii&amp;charset=ISO-8859-8">ISO-8859-8 Hebrew (same as previous)</a>
	<li><a href="http://josefsson.org/idn.php?data=%D0%BF%D0%BE%D1%87%D0%B5%D0%BC%D1%83%D0%B6%D0%B5%D0%BE%D0%BD%D0%B8%D0%BD%D0%B5%D0%B3%D0%BE%D0%B2%D0%BE%D1%80%D1%8F%D1%82%D0%BF%D0%BE%D1%80%D1%83%D1%81%D1%81%D0%BA%D0%B8&amp;mode=toascii&amp;charset=UTF-8">UTF-8 Russian (Cyrillic)</a>
	<li><a href="http://josefsson.org/idn.php?data=%D0%CF%DE%C5%CD%D5%D6%C5%CF%CE%C9%CE%C5%C7%CF%D7%CF%D2%D1%D4%D0%CF%D2%D5%D3%D3%CB%C9&amp;mode=toascii&amp;charset=KOI8-R">KOI8-R Russian Cyrillic (same as previous)</a>
	<li><a href="http://josefsson.org/idn.php?data=%D0%CF%DE%C5%CD%D5%D6%C5%CF%CE%C9%CE%C5%C7%CF%D7%CF%D2%D1%D4%D0%CF%D2%D5%D3%D3%CB%C9&amp;mode=toascii&amp;charset=ECMA-CYRILLIC">ECMA-CYRILLIC Russian Cyrillic (same as previous)</a>
	<li><a href="http://josefsson.org/idn.php?data=T%E1%BA%A1isaoh%E1%BB%8Dkh%C3%B4ngth%E1%BB%83ch%E1%BB%89n%C3%B3iti%E1%BA%BFngVi%E1%BB%87t&amp;mode=toascii&amp;charset=UTF-8">UTF-8 Vietnamese</a>
	<li><a href="http://josefsson.org/idn.php?data=t%D5isaoh%F7kh%F4ngth%ACch%EFn%F3iti%AAngvi%AEt&amp;mode=toascii&amp;charset=VISCII">VISCII Vietnamese (same as previous)</a>
	<li><a href="http://josefsson.org/idn.php?data=%E3%81%B2%E3%81%A8%E3%81%A4%E5%B1%8B%E6%A0%B9%E3%81%AE%E4%B8%8B2&amp;mode=toascii&amp;charset=UTF-8">UTF-8 Japanese</a>
	<li><a href="http://josefsson.org/idn.php?data=%A4%D2%A4%C8%A4%C4%B2%B0%BA%AC%A4%CE%B2%BC2&amp;mode=toascii&amp;charset=EUC-JP">EUC-JP Japanese (same as previous)</a>
	<li><a href="http://josefsson.org/idn.php?data=%82%D0%82%C6%82%C2%89%AE%8D%AA%82%CC%89%BA2&amp;mode=toascii&amp;charset=SJIS">SHIFT_JIS Japanese (same as previous)</a>
	<li><a href="http://josefsson.org/idn.php?data=Pro%C4%8Dprost%C4%9Bnemluv%C3%AD%C4%8Desky&amp;mode=toascii&amp;charset=UTF-8">UTF-8 Czech</a>
	<li><a href="http://josefsson.org/idn.php?data=Pro%E8prost%ECnemluv%ED%E8esky&amp;mode=toascii&amp;charset=ISO-8859-2">ISO-8859-2 Czech (same as previous)</a>
	<li><a href="http://josefsson.org/idn.php?data=%E0%A4%AF%E0%A4%B9%E0%A4%B2%E0%A5%8B%E0%A4%97%E0%A4%B9%E0%A4%BF%E0%A4%A8%E0%A5%8D%E0%A4%A6%E0%A5%80%E0%A4%95%E0%A5%8D%E0%A4%AF%E0%A5%8B%E0%A4%82%E0%A4%A8%E0%A4%B9%E0%A5%80%E0%A4%82%E0%A4%AC%E0%A5%8B%E0%A4%B2%E0%A4%B8%E0%A4%95%E0%A4%A4%E0%A5%87%E0%A4%B9%E0%A5%88%E0%A4%82&amp;mode=toascii&amp;charset=UTF-8">UTF-8 Hindi Devanagari</a>
	<li><a href="http://josefsson.org/idn.php?data=%E0%BA%9E%E0%BA%B2%E0%BA%AA%E0%BA%B2%E0%BA%A5%E0%BA%B2%E0%BA%A7&amp;mode=toascii&amp;charset=UTF-8">UTF-8 Lao</a>
	<li><a href="http://josefsson.org/idn.php?data=bon%C4%A1usa%C4%A7%C4%A7a&amp;mode=toascii&amp;charset=UTF-8">UTF-8 Maltese Malti</a>
	<li><a href="http://josefsson.org/idn.php?data=bon%F5usa%B1%B1a&amp;mode=toascii&amp;charset=ISO-8859-3">ISO-8859-3 Maltese Malti (same as previous)</a>
	<li><a href="http://josefsson.org/idn.php?data=%CE%B5%CE%BB%CE%BB%CE%B7%CE%BD%CE%B9%CE%BA%CE%AC&amp;mode=toascii&amp;charset=UTF-8">UTF-8 Greek</a>
	<li><a href="http://josefsson.org/idn.php?data=%E5%EB%EB%E7%ED%E9%EA%DC&amp;mode=toascii&amp;charset=ISO-8859-7">ISO-8859-7 Greek (same as previous)</a>
	<li><a href="http://josefsson.org/idn.php/?data=%E5%8D%81%E2%80%A4com&profile=Nameprep&mode=toascii&debug=on&charset=UTF-8&lastcharset=UTF-8">U+2024 dot separator example</a>
    </ul>


    <hr>
    <h2>Error codes</h2>

<pre>

  enum
  {
    PUNYCODE_SUCCESS = 0,
    PUNYCODE_BAD_INPUT,		/* Input is invalid.                       */
    PUNYCODE_BIG_OUTPUT,	/* Output would exceed the space provided. */
    PUNYCODE_OVERFLOW		/* Input needs wider integers to process.  */
  };


  typedef enum
  {
    STRINGPREP_OK = 0,
    /* Stringprep errors. */
    STRINGPREP_CONTAINS_UNASSIGNED = 1,
    STRINGPREP_CONTAINS_PROHIBITED = 2,
    STRINGPREP_BIDI_BOTH_L_AND_RAL = 3,
    STRINGPREP_BIDI_LEADTRAIL_NOT_RAL = 4,
    STRINGPREP_BIDI_CONTAINS_PROHIBITED = 5,
    /* Error in calling application. */
    STRINGPREP_TOO_SMALL_BUFFER = 100,
    STRINGPREP_PROFILE_ERROR = 101,
    STRINGPREP_FLAG_ERROR = 102,
    STRINGPREP_UNKNOWN_PROFILE = 103,
    /* Internal errors. */
    STRINGPREP_NFKC_FAILED = 200,
    STRINGPREP_MALLOC_ERROR = 201
  } Stringprep_rc;

  typedef enum
  {
    IDNA_SUCCESS = 0,
    IDNA_STRINGPREP_ERROR = 1,
    IDNA_PUNYCODE_ERROR = 2,
    IDNA_CONTAINS_NON_LDH = 3,
    /* Workaround typo in earlier versions. */
    IDNA_CONTAINS_LDH = IDNA_CONTAINS_NON_LDH,
    IDNA_CONTAINS_MINUS = 4,
    IDNA_INVALID_LENGTH = 5,
    IDNA_NO_ACE_PREFIX = 6,
    IDNA_ROUNDTRIP_VERIFY_ERROR = 7,
    IDNA_CONTAINS_ACE_PREFIX = 8,
    IDNA_ICONV_ERROR = 9,
    /* Internal errors. */
    IDNA_MALLOC_ERROR = 201
  } Idna_rc;
</pre>

    <hr>
  </body>
</html>
