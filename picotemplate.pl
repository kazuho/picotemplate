#! /usr/bin/perl

use strict;
use warnings;

my $srcfn = shift @ARGV;
die "no filename"
    unless $srcfn;

my ($push_expr, $push_str) = convfunc($srcfn);

$srcfn =~ m{^(.*/)_([^/]+)$}
    or die "filename should start with an underscore";
my $dstfn = "$1$2";

open my $srcfh, "<", $srcfn
    or die "failed to open file:$srcfn";
open my $dstfh, ">", $dstfn
    or die "failed to open file:$dstfn";

while (my $line = <$srcfh>) {
    if ($line =~ /^\?/) {
        my $markup = $';
        my @st;
        for my $token (split /(<\?=.*?\?>)/, $markup) {
            if ($token =~ /^\<\?=\s*(.*?)\s*\?>$/) {
                push @st, $push_expr->($1);
            } elsif ($token ne "") {
                push @st, $push_str->($token);
            }
        }
        print $dstfh join(" ", @st), "\n";
    } else {
        print $dstfh "$line";
    }
}

close $srcfh;
close $dstfh;

sub convfunc {
    my $srcfn = shift;
    if ($srcfn =~ /\.pl$/) {
        # perl
        return (
            # push_expr function
            sub {
                my $src = shift;
                return qq{\$_ = ($src); s/\\n\$//; \$output .= \$_;};
            },
            # push_str function
            sub {
                my $str = shift;
                $str = quotemeta $str;
                return qq{\$output .= "$str";};
            },
        );
    } elsif ($srcfn =~ /\.(?:cc|cpp|cxx)$/) {
        # C++
        return (
            # push_expr function
            sub {
                my $src = shift;
                return qq^{std::string _r($src); if (! _r.empty() && _r.back() == '\n') _r.erase(_r.size() - 1); _.append(_r);}^;
            },
            # push_str function
            sub {
                my $str = shift;
                my $str = shift;
                $str =~ s/([\\'"])/\\$1/gs;
                $str =~ s/\n/\\n/gs;
                return qq{_.append("$str");};
            },
        );
    } elsif ($srcfn =~ /\.jsx?$/) {
        # JavaScript or JSX
        return (
            # push_expr function
            sub {
                my $src = shift;
                return qq{_ += ($src).replace(/\\n\$/, "");};
            },
            # push_str function
            sub {
                my $str = shift;
                $str =~ s/([\\'"])/\\$1/gs;
                $str =~ s/\n/\\n/gs;
                return qq{_ += "$str";};
            },
        );
    } else {
        die "unknown filetype!";
    }
}
