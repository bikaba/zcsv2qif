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
my $dateIdx = 0;
my $categoryIdx = 3;
my $accountIdx = 4;
my $memoIdx = 6;
my $payeeIdx = 8;
my $amountIdx = 11;

# read transactions
my @records;
my $pattern = "";
my $csvref = $csv->getline_all(*STDIN);
my @sorted = sort { $a->[$dateIdx] cmp $b->[$dateIdx]
                                    ||
                    $a->[$payeeIdx] cmp $b->[$payeeIdx] } @$csvref;

foreach my $row (@sorted) {
#    print "$row->[$dateIdx],$row->[$payeeIdx],$row->[$memoIdx],$row->[$amountIdx]\n";

	# create new transaction
	if (length($pattern) == 0 or $row->[$payeeIdx] !~ /$pattern/) {	
		push @records, $record if length($pattern) > 0;
		$pattern = $row->[$payeeIdx];
		undef($record);
		my $record = {};
	}
	$record->{header} = "Type:Bank";
	$record->{payee} = $row->[$payeeIdx];
	$record->{total} = 0;
	$record->{date} = $row->[$dateIdx];
	$record->{account} = $row->[$accountIdx];

	# create new split
	my $split = {
		"memo"		=> $row->[$memoIdx],
		"amount"	=> -($row->[$amountIdx]),
		"category"	=> $row->[$categoryIdx],
	};
	push @{$record->{splits}}, $split;
}
push @records, $record if $pattern !~ /""/;

$csv->eof or $csv->error_diag();
$csv->eol ("\r\n");

my $account = {
	"header"		=> "Account",
	"name"			=> "",
	"description"	=> "",
	"type"			=> "Bank",
};

foreach my $record (@records) {
	if ($account->{name} ne $record->{account}) {
		$account->{name} = $record->{account};
		$account->{description} = $record->{account};
		$out->header($account->{header});
		$out->write($account);
	}
	delete $record->{account};
	$out->header($record->{header});
	$out->write($record);
}

$out->close;
