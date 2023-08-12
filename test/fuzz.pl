#!/usr/bin/env perl

use strict;

use IPC::Open2;
use Session::Token;

my $harnessType = shift || die "please provide harness type (cpp, js, etc)";
my $idSize = shift || 16;


my $harnessCmd;

if ($harnessType eq 'cpp') {
    $harnessCmd = './cpp/harness';
} elsif ($harnessType eq 'js') {
    $harnessCmd = 'node js/harness.js';
} else {
    die "unknown harness type: $harnessType";
}


srand($ENV{SEED} || 0);
my $stgen = Session::Token->new(seed => "\x00" x 1024, alphabet => '0123456789abcdef', length => $idSize * 2);


my $iters = $ENV{ITERS} // 1;

my $minRecs = $ENV{MIN_RECS} // 1;
my $maxRecs = $ENV{MAX_RECS} // 10_000;
die "MIN_RECS > MAX_RECS" if $minRecs > $maxRecs;
$minRecs = $maxRecs = $ENV{RECS} if $ENV{RECS};

my $prob1 = $ENV{P1} // 1;
my $prob2 = $ENV{P2} // 1;
my $prob3 = $ENV{P3} // 98;

{
    my $total = $prob1 + $prob2 + $prob3;
    die "zero prob" if $total == 0;
    $prob1 = $prob1 / $total;
    $prob2 = $prob2 / $total;
    $prob3 = $prob3 / $total;
}


for (my $i = 0; $i < $iters; $i++) {
    my $ids1 = {};
    my $ids2 = {};

    my $pid = open2(my $outfile, my $infile, $harnessCmd);

    my $num = $minRecs + rnd($maxRecs - $minRecs);

    for (1..$num) {
        my $mode;

        my $modeRnd = rand();

        if ($modeRnd < $prob1) {
            $mode = 1;
        } elsif ($modeRnd < $prob1 + $prob2) {
            $mode = 2;
        } else {
            $mode = 3;
        }

        my $created = 1677970534 + rnd($num);
        my $id = $stgen->get;

        $ids1->{$id} = 1 if $mode == 1 || $mode == 3;
        $ids2->{$id} = 1 if $mode == 2 || $mode == 3;

        print $infile "$mode,$created,$id\n";
    }

    close($infile);

    while (<$outfile>) {
        if (/^xor,(HAVE|NEED),(\w+)/) {
            my ($action, $id) = ($1, $2);

            if ($action eq 'NEED') {
                die "duplicate insert of $action,$id" if $ids1->{$id};
                $ids1->{$id} = 1;
            } elsif ($action eq 'HAVE') {
                die "duplicate insert of $action,$id" if $ids2->{$id};
                $ids2->{$id} = 1;
            }
        }
    }

    waitpid($pid, 0);
    my $child_exit_status = $?;
    die "failure running test harness" if $child_exit_status;

    for my $id (keys %$ids1) {
        die "$id not in ids2" if !$ids2->{$id};
    }

    for my $id (keys %$ids2) {
        die "$id not in ids1" if !$ids1->{$id};
    }

    print "\n-----------OK-----------\n";
}


sub rnd {
    my $n = shift;
    return int(rand() * $n);
}