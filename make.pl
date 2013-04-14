#!/usr/bin/perl

# DcsPerfA - DataCore Server Performance Analyzer
#
# Authors:
#   Thomas Liske <thomas@fiasko-nw.net>
#
# Copyright Holder:
#   2013 (C) Thomas Liske [http://fiasko-nw.net/~thomas/]
#
# License:
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this package; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
#

use Date::Parse;
use Text::Template;
use JSON;
use strict;
use warnings;

die "Usage: $0 <from> <to> <defs.csv> <data.csv> <output dir>\n" unless($#ARGV == 4);

use constant {
    GNUPLOT_TIME_OFFSET => 946684800,
};

my ($from, $to, $fn_defs, $fn_data, $outdir) = @ARGV;
my $t1 = str2time($from);
my $t2 = str2time($to);
$outdir =~ s@/$@@;
die "Could not read definition file '$fn_defs'!\n" unless (-r $fn_defs);
die "Could not read data file '$fn_data'!\n" unless (-r $fn_data);
mkdir($outdir);
die "Output path '$outdir' is not a directory!\n" unless(-d $outdir);

print STDERR 'Filter range: ', scalar localtime($t1), ' - ', scalar localtime($t2), "\n";


print STDERR "Reading definitions...\n";
my %classes;
my %names;
my %deltas;
open(HDEFS, $fn_defs) || die "Could not open '$fn_defs': $!\n";
while(<HDEFS>) {
    chomp;
    my ($k1, $k2, $type, $pishort, $pilong, $counter, $ctype) = split(/[,\t]/);
    die if(exists($names{$k1}) && exists($names{$k1}->{$k2}));
    $names{$k1}->{$k2} = "$pilong:$counter";

    $classes{$type}->{$pilong}->{$counter} = {
	counter => $counter,
	ctype => $ctype,
	k1 => $k1,
	k2 => $k2,
    };

    $deltas{$k1}->{$k2}++ if($ctype eq 'Delta');
}
close(HDEFS);


print STDERR "Reading data...\n";
my %vals;
my %keys;
my $key;
open(HDATA, $fn_data) || die "Could not open '$fn_data': $!\n";
while(<HDATA>) {
    chomp;
    s/\r//;
    my ($ts, $k1, $k2, $data) = split(/[,\t]/);
    $ts = int($ts/10000 + 0.5)*10;

    next unless($ts >= $t1 && $ts <= $t2);

    $vals{$ts}->{$k1}->{$k2} = $data;
    $keys{$k1}->{$k2}++;
}
close(HDATA);


my $json = JSON->new();
$json->canonical(1);
$json->shrink(1);

print STDERR "Creating JSON output...\n";
mkdir("$outdir/json/");

my @k1 = sort {$a <=> $b} keys %keys;
my $idx = 2;
foreach my $k1 (@k1) {
    foreach my $k2 (sort {$a <=> $b} keys %{$keys{$k1}}) {
	my $JSO = "$outdir/json/$k1-$k2.json";
	open(HOUT, '>', $JSO) || die "Could not create '$JSO': $!\n";

	my $last;
	my @data;
	foreach my $ts (sort {$a <=> $b} keys %vals) {

	    my $v = $vals{$ts}->{$k1}->{$k2};

	    if($deltas{$k1}->{$k2}) {
		if(defined($last)) {
		    $v /= $ts - $last;
		}
		else {
		    $v = '';
		}
	    }

	    my %data = (
		t => $ts,
		v => $v,
	    );
	    push(@data, \%data);

	    $last = $ts;
	}
	print HOUT $json->encode(\@data);
	close(HOUT);
    }
}

print STDERR "Creating index.html...\n";

my $t = Text::Template->new(TYPE => 'FILEHANDLE', SOURCE => \*DATA)
    or die "Couldn't construct template: $Text::Template::ERROR\n";

my $IDX = "$outdir/index.html";
open(HIDX, '>', $IDX) || die "Could not create '$IDX': $!\n";

my $res = $t->fill_in(
    OUTPUT => \*HIDX,
    HASH => {
	classes => \%classes,
    },
);

die "Couldn't fill in template: $Text::Template::ERROR\n" unless (defined($res));

close(HIDX);

__END__
{
    sub create_options() {
	$OUT = '';

	foreach my $type (sort keys %classes) {
	    $OUT .= "<optgroup label=\"$type\">\n";
	    foreach my $pilong (sort keys %{$classes{$type}}) {
		$OUT .= "<optgroup label=\"$pilong\" style=\"text-indent:1em;\">\n";
		foreach my $counter (sort keys %{$classes{$type}->{$pilong}}) {
		    $OUT .= "<option value=\"$classes{$type}->{$pilong}->{$counter}->{k1}-$classes{$type}->{$pilong}->{$counter}->{k1}\">$counter</option>\n";
		}
		$OUT .= "</optgroup>\n";
	    }
	    $OUT .= "</optgroup>\n";
	}

	return $OUT;
    }
}
<html>
<head>
    <script src="include/d3/d3.min.js"></script>
</head>
<body>

<table>
    <tr>
	<th>X:</th>
	<td>
	    <select name="dcs_selx">
		<option value="0">Time</option>
		{create_options();}
	    </select>
	</td>
    </tr>
    <tr>
	<th>Y:</th>
	<td>
	    <select name="dcs_sely" multiple="1" size="10">
		<option value="0">Time</option>
		{create_options();}
	    </select>
	</td>
    </tr>
    <tr>
	<th>Z:</th>
	<td>
	    <select name="dcs_selz">
		<option value="0">Time</option>
		{create_options();}
	    </select>
	</td>
    </tr>
</table>

<hr />
<small>{scalar localtime().' - <code>'.join(' ', $0, @ARGV)}</code></small>
</body>
</html>
