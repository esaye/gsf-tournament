#!/usr/bin/perl

# Copyright (C) 2014 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package Ratings::WESPA;

use strict;
use warnings;

use Ratings::WESPA;

our (@ISA) = qw(Ratings);

=pod

=head1 NAME

Ratings::WESPA - code related to WESPA rating system

=head1 SYNOPSIS

  my $name = Ratings::WESPA::Canonicalise($string);
  
=head1 ABSTRACT

Ratings::WESPA contains utility functions related to the WESPA rating system.

=cut

=head1 DESCRIPTION

=over 4

=cut

my (%gNameFixes) = (
  # .t file => TSH version of WESPA list
  # 'POH, YING MING' => 'Ying Ming, Poh', # see AUPAIR.pm
  'TOOLE, B A' => 'Toole, Betty',
  'KWOFIE, CARLOS OTOO' => 'OTOO, CARLOS',
  'OSADOLOR, CHARLES OSAMWONYI' => 'OS, CHARLES OSAMWONYI',
  'EBI, AWEH' => 'AWEH, EBI',
  'WILKIE, JAMES' => 'WILKIE, JIM',
  'ERBPRASARTSOOK, AKEGAPUN' => 'Erbpras, Akegapun',
  'SHAUKAT, NOOR UN NISA' => 'Shaukat, Noor',
  'KOSANWATTANA, WASINTORN' => 'Kosanwatt, Wasinthorn',
  'VATJARANURATHORN, NAPAT' => 'Vatjaranuratho, Napat',
  'KHAN, ABDUL MAJID' => 'Khan, Abdul',
  'MOSES PETER, MOSES' => 'Peter, Moses',
  'MANASE, JOSHUA OTIENO' => 'Otieno, Manase',
  'QUICKPEN, BEN' => 'Ben, Quickpen',
  'LEE, JENNIFER M' => 'Lee, Jennifer',
  'NDERITU, PATRICK GITONGA' => 'Nderitu, Gitonga',
  'OWOLABI, PHILIPS LUKEMAN' => 'Owolabi, Lukeman',
  'CHAKRAVARTHY, RANGANATHAN' => 'Chakrav, Ranganathan',
  'NGALA, LUBUNDA' => 'Lubunda, Ngala',
  'CHITUNDU, MULENGA' => 'Mulenga, Chitundu',
  'WENWA, AKINYI' => 'Akinyi, Wenwa',
  'NDUNGU, STANLEY NJOROGE' => 'Njoroge, Stanley',
  'ONANI, MAGWANGA' => 'Magwanga, Onani',
  'UMOH, BASSEY' => 'Bassey, Umoh',
  'KHOO, DARREN' => 'Khoo, Beng Way',
  'TANTSIRIWAT, SUPITCHAYA' => 'Tantisiri, Supitchaya',
  'POLAK SCOWCROFT, CAROLINE' => 'Scowcroft, Caroline',
  'WOO, MARC JUN HOWE' => 'Marc Woo, Jun Howe',
  'CHANG, ANDREW CHING WEI' => 'Chang, Ching Wei',
  'TSANG, JASON WAI YIN' => 'Jason Tsang, Wai Yin',
  'LODDER, CORNELIA' => 'Lodder, Cori',
  'KINGDOM, ROSE MARIE' => 'Kingdom, Rose',
  'PEARSE, ANGELA' => 'Pearse, Angie',
  'GARBA, SULAIMAN GORA' => 'Sulaiman, Gora',
  'KEET, DUNCAN' => 'Keet, Dunx',
  'LE BRON, DENISE' => 'LeBron, Denise',
  'BAGINSKI, RONALD' => 'Baginski, Ron',
  'THANASARNWIMOL, MANEEDA' => 'Tanasarn, Maneeda',
  'KWANSAK, AKKARAPOL' => 'Kwhansak, Akkarapol',
  'SUKSAENSAMRAN, WORASIT' => 'Suksaensam, Worasit',
  'BOONSIRIPHANT, SITTICHOK' => 'Boonsiri, Sitthicok',
  'ROJPHONGKASEM, JAKKAPAN' => 'Rojphongkas, Jakkapan',
  'PHOSAI, SOMPONG' => 'Phosai, Somphong',
  'SRISUWANNAHONG, KOMSAN' => 'Srisuwanna, Komsan',
  'HROMNIK, TRISTAN' => 'Tristan, Ze',
  'RICHARDS, PAUL' => 'Richards AUS, Paul', # use with caution
  'CHINNAIYAH, SURESH THEVAKUMAR SAMUEL' => 'Chinnaiyah, Suresh', 
  'ETIM, NSIKAK SOLOMON' => 'Etim, Nsikan', 
  'ETIM, NSIKAN SOLOMON' => 'Etim, Nsikan', 
  'WITHERS, BEN' => 'Withers, Benjamin', 
  'AKA, TOKE' => 'Aka, Olobatoke', 
  'ANANGA, YAWO' => 'Ananga, Yawo Takyi',
  'AGANABA, MBELEOKPO MATHEW', 'Aganaba, Mbeleokpo',
  'BALOGUN, GBOYE' => 'Balogun, Alex Gboye',
  'BALOGUN, RASHEED OLAJIDE' => 'Balogun, Rasheed',
  'CABA, CATALIN' => 'Caba, Catalin-Eugen',
  'CARTER, GERALD' => 'Carter, Gerry',
# 'CHEAH, SIU HEAN' => 'Hean, Cheah Siu',
  'DE CASTRO, PHYLLIS' => 'DeCastro, Phyllis',
  'FRENDO, PAUL' => 'Frendo, Pawlu',
  'GOLDMAN, STUART' => 'Goldman, Stu',
  'HOVELMEIER, TREVOR MARK' => 'Hovelmeier, Trevor',
  'ILORI, OLAWALE' => 'Ilori, Wale',
  'KHAN, RASHID ATEEQ' => 'Khan, Rasheed',
  'LAMABADUSURIYA, HARSHAN' => 'Lamabad, Harshan',
  'LAWRENCE, TIM' => 'Lawrence, Timothy',
  'LEE, JENNIFER:AA004823' => 'Lee, Jennifer',
# 'LIEW, KIAN BOON' => 'Boon, Liew Kian',
  'LIM, SHALYN' => 'Lim, Sha Lyn',
  'MACKENZIE, JAYNE' => 'MacKenzie, Jayne',
# 'MORRIS, PAM' => 'Morris, Pamela',
  'MPUNDU, PATRICK MULEMENA' => 'Mpundu, Patrick',
  'NELKON, PHILIP' => 'Nelkon, Phil',
# 'NI BHRIAIN, BRID' => 'Bhriain, Brid Ui',
  'NI BHRIAIN, BRID' => 'O\'Brien, Breda',
  'OKWELOGU, CHINEDU NOSIKE' => 'Okwelogu, Chinedu',
  'OLAUGHLIN, JOHN' => 'O\'Laughlin, John',
  'ONG, SUANNE' => 'Suanne, Ong',
  'PUTTICK, JUDY' => 'Puttick, Judith',
  'RIO, ODETTE CARMINA' => 'Rio, Odette',
  'SHIM, YEN NEE' => 'Nee, Shim Yen',
  'STRAWBRIDGE, CHRISTINE' => 'Strawb, Christine',
# 'SULAIMAN, MOHAMMAD' => 'Sulaiman, Mohammed',
  'TALBOT, RODNEY' => 'Talbot, Rod',
# 'TAN, JIN CHOR' => 'Jin Chor, Tan',
  'TATE, RAYMOND' => 'Tate, Ray',
  'TOH, WEIBIN' => 'Weibin, Toh',
  'PATTANASUWANNA, SINATARN' => 'Pattanasuwa, Sinatarn',
  'VELLA-LAURENTI, NICKY' => 'Laurenti, Nicky Vella',
  'WEE, MING HUI HUBERT' => 'Wee, Hubert',
  'WEE, HUBERT MING HUI' => 'Wee, Hubert',
  'WIEGAND, DAVE' => 'Wiegand, David',
  'YEO, KIEN HUNG' => 'Yeo, Kian Hung',
  'USAKIEWICZ, WOJTEK' => 'Usakiewicz, Wojciech',
# 'ZXQKJ, WINTER' => 'Winter',

  'TACHIE-MENSON, CHARLES' => 'Tachie, Charles',
  'KRAMER, JIM' => 'Kramer, James',
  'CAVENAGH, NICHOLAS' => 'Cavenagh, Nick',
  'WANNIARACHCHI, LAKSHAN' => 'Wanni, Lakshan',
  'ADAMSON, TIM' => 'Adamson, Timothy',
  'ADDO-QUAYE, GEORGE' => 'Addo, George',
  'ASSARAT, SUTHIRAPAN' => 'Assarat, Suthiraphan',
  'BARAMEEMUANG, THITIPOL' => 'Barameem, Thitipol',
  'BASSETT-BOUCHARD, CONRAD' => 'Bassett, Conrad',
  'BOONSIRIPHAN, SITTHICHOKE' => 'Boonsiri, Sitthicok',
  'CHAROENPRASATKUL, LATCHA' => 'Chalernpasart, Latcha',
  'CHINRUNGROJ, NATTAWUTH' => 'Chinrung, Nattawuth',
  'DANIEL, ROBIN POLLOCK' => 'Daniel, Robin',
  'EDWIN-MUGISHA, PHILLIP' => 'Edwin-Mugish, Phillip',
  'ITTHI-AREE, CHOLLAPAT' => 'Itthiaree, Chollapat',
  'KHONGTHANARAT, CHARNRIT' => 'Khongthan, Charnrit',
  'KHONGTHANARAT, PREEDEE' => 'Khongthanara, Preedee',
  'KHWANSAK, AKKARAPOL' => 'Kwhansak, Akkarapol',
  'KUKIETTIKULCHAI, THANAPONG' => 'Kukiet, Thanapong',
  'METHASET, ARUN' => 'Methaseth, Arun',
  'MOOLASARN, PHUTTAPHONG' => 'Moolasar, Phuttaphong',
  'PAEPOLSIRI, TAWAN' => 'Paepholsiri, Tawan',
  'PANYASOPHONLERT, KOMOL' => 'Panyasoponlert, Komol',
  'PATTANASUWANNA, SINATARN' => 'Pattanasuwa, Sinatarn',
  'PHIPHATBOONSERM, MANOP' => 'Phiphat, Manop',
  'PICHAIRATTANAPONG, ORRAKANYA' => 'Pichairatta, Ornkanya',
  'SOSSEH, ABRAHAM EBI' => 'Sosseh, Abraham',
  'SUKHUMRATTANAPORN, CHARNWIT' => 'Sukhu, Charnwit',
  'SUKSANSUMRAN, WORASIT' => 'Suksaensam, Worasit',
  'SUPHAPHIBUNKUN, TANASAK' => 'Supaphibunk, Tanasak',
  'SUPPAPITTATORN, AKARADECH' => 'Suppapittatorn, Akaradech',
  'TANASANVIMOL, MANEEDA' => 'Tanasarn, Maneeda',
  'TANASANVIMOL, WEERANEE' => 'Tanasarn, Weeranee',
  'THIANKAROJANAKUL, THANATCHAPORN' => 'Thiank, Thanatchaporn',
  'THIANKAROJANAKUL, THANAPORN' => 'Thiankaroj, Thanaporn',
  'THIENKAROJANAKUL, KAMOL' => 'Tienkarojan, Kamol',
  'THIVAVARNVONGS, THAVATCHAI' => 'Tivava, Thavachai',
  'TREEPOONSUK, NUT' => 'Treepoonsuk, Nutt',
  'TRITIPTHANAKUL, PACHARA' => 'Tritipthanak, Pachara',
  'VICARY, CHRISTOPHER' => 'Vicary, Chris',
  'VONGTHANASOONTHORN, VISAN' => 'Vongthanasun, Visan',
  'WUTHINITIKORNKIT, CHAIWAT' => 'Wuthinitikor, Chaiwat',
# 'SRICHAWLA, DANIEL' => 'Srichwala, Daniel',
# 'WORAPOTPISUT, CHARAE' => 'Worapotpisut, Charae',
#   'WORAPOTPISUT, CHARAS' => 'Worapot, Charas',

  # Pakistani players
  'ABBASI, ATIYA' => 'Abbasi, Atya',
  'ABBASI, AHMED ABDULLAH' => 'Abbasi, Abdullah',
  'AFFAN, MOHAMMED' => 'Shahzad, Affan',
  'AHMAD, MINHAJ' => 'Ahmad, Minhaj Uddin',
  'ANSARI, SHAHROZ' => 'Ansari, Shahroz Zamir',
  'BAIG, MOIZ' => 'Baig, Moizullah',
  'BAIG, WASEEM' => 'Baig, Mirza Waseem',
  'HADI, HAMMAD' => 'Khan, Hammad Hadi',
  'HADI, HASHAM' => 'Khan, Hasham Hadi',
  'HADI, HASSAN' => 'Khan, Hassan Hadi',
  'HUDA, TAHA' => 'Huda, Syed Taha Ul',
  'JAMSHAID, YASIR' => 'Jamshaid, Syed Yasir',
  'KHATTAK, AQILA' => 'Khattak, Aqila Jamil',
  'KHATTI, RAFIQ' => 'Khatri, Rafique',
  'MERCHANT, ASAD' => 'Merchant, Asad Raza',
  'MIRZA, JAVERIA' => 'Mirza, Javeria Arshad',
  'MUHAMMAD, VALI' => 'Khubaib, Vali',
  'PABANEY, FATIMA' => 'Pabaney, Fatima Arif',
  'RIZVI, ASIF' => 'Rizvi, Syed Asif',
  'TALHA, MUHAMMAD' => 'Arif, Muhammad Talha',
  'HASSAN, MIRZA TAHA' => 'Taha, Mirza',
  'SANAULLAH, DANIYAL' => 'Sanaullah, Danial',

  );

sub Canonicalise ($);

=item $name = Ratings::WESPA::Canonicalise($string);

Convert a NASPA or ABSP name to WESPA form.

=cut

sub Canonicalise ($) {
  my $s = shift;
  my $canon = $gNameFixes{uc $s} || $s;
  return $canon;
  }

=back

=cut

=head1 BUGS

The necessity of the existence of Canonicalise() is unfortunate.

=cut

1;

