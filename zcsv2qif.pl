#use strict;
use warnings;
use utf8;
use bytes();

#binmode STDOUT, ":encoding(utf8)";
#binmode STDIN, ":encoding(utf8)";
#binmode STDERR, ':encoding(utf8)';
#binmode STDIN, ":encoding(shiftjis)";	# shift-jis

use Text::CSV;
use Finance::QIF;
 
my $qiffile = "new.qif";
my $csv = Text::CSV->new ( { binary => 1, eol => $/ } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();
my $out = Finance::QIF->new( file => ">" . $qiffile, );

# skip header
my $row = $csv->getline( *STDIN ) ;

# Zaim CSV row Index values
my $dateIdx = 0;			# 日付
my $categoryIdx = 2;		# カテゴリ
my $subCategoryIdx = 3;		# カテゴリの内訳
my $accountIdx = 4;			# 支払元
my $itemIdx = 6;			# 品目
my $memoIdx = 7;			# メモ
my $payeeIdx = 8;			# お店
my $amountIdx = 11;			# 支出

# read transactions
my @records;
my $csvref = $csv->getline_all(*STDIN);
my @sorted = sort { $a->[$accountIdx] cmp $b->[$accountIdx] 
                                    ||
					$a->[$payeeIdx] cmp $b->[$payeeIdx]
                                    ||
					$a->[$dateIdx] cmp $b->[$dateIdx] } @$csvref;

#my %record = (
#	payee   => "",
#	account => ""
#);
my %record;
$record{payee} = "";
$record{account} = "";

foreach my $row (@sorted) {
#    print "$row->[$dateIdx],$row->[$payeeIdx],$row->[$memoIdx],$row->[$amountIdx]\n";
#	print $record{payee} . " : " . $record{account} . "\n"  if $record{payee} ne "";

	# create new transaction
	# 直前のrecordと日付、支払先または支払元が異なる場合に次のレコードとする
	if (($row->[$dateIdx] ne $record{date}) ||
		($row->[$payeeIdx] ne $record{payee}) ||
		($row->[$accountIdx] ne $record{account})) {
		my %record_save = %record;
		push @records, \%record_save if $record{payee} ne "";
		$record{header} = "Type:Bank";
		$record{payee} = $row->[$payeeIdx];
		$record{total} = 0;
		$record{date} = $row->[$dateIdx];
		$record{account} = $row->[$accountIdx];
		$record{splits} = [];
	}

	# create new split
	my $split = {
		'memo'		=> $row->[$itemIdx] . $row->[$memoIdx],
		'amount'	=> -($row->[$amountIdx]),
		'category'	=> $row->[$categoryIdx] . ":" . $row->[$subCategoryIdx],
	};
	push $record{splits}, $split;
}
push @records, \%record;

$csv->eof or $csv->error_diag();
$csv->eol ("\r\n");

my $account = {
	"header"		=> "Account",
	"name"			=> "",
	"description"	=> "",
	"type"			=> "Bank",
};

foreach my $recref (@records) {
	if ($account->{name} ne $recref->{account}) {
		$account->{name} = $recref->{account};
		$account->{description} = $recref->{account};
		$out->header($account->{header});
		$out->write($account);
	}
	$out->header($recref->{header});
	$out->write($recref);
}

$out->close;
