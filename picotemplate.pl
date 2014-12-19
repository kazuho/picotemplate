#! /usr/bin/perl

# Copyright (c) 2012-2014 Kazuho Oku
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

use strict;
use warnings;
use Getopt::Long;

my ($opt_conf, $opt_help);
GetOptions(
    "conf=s" => \$opt_conf,
    help     => \$opt_help,
) or exit 1;

if ($opt_help) {
    print << "EOT";
Usage:
    $0 [--conf=<script-file>] <src-file>

Description:
    Applies necessary conversions against <src-file> (the name should start
    with an underscore) and emits the result.  The result is stored in a file
    which is given the same name as <src-file> omitting the preceeding
    underscore.

Options:
    --conf=<script-file>  if set, reads configuration from <script-file>,
                          otherwise the configuration is taken from the
                          extension of <src-file>

EOT
    exit 0;
}

my $srcfn = shift @ARGV;
die "no filename"
    unless $srcfn;

our ($push_expr, $push_void_expr, $push_str);

if ($opt_conf) {
    require $opt_conf;
} else {
    ($push_expr, $push_void_expr, $push_str) = convfunc($srcfn);
}

$srcfn =~ m{^(.*/)_([^/]+)$}
    or die "filename should start with an underscore";
my $dstfn = "$1$2";

open my $srcfh, "<", $srcfn
    or die "failed to open file:$srcfn";
open my $dstfh, ">", $dstfn
    or die "failed to open file:$dstfn";

my $pending = '';
my $flush_pending = sub {
    return if $pending eq '';
    print $dstfh $push_str->($pending), map { "\n" } @{[ $pending =~ /\n/g ]};
    $pending = '';
};
while (my $line = <$srcfh>) {
    if ($line =~ /^\?/) {
        my $markup = $';
        for my $token (split /(<\?[=!].*?\?>)/, $markup) {
            if ($token =~ /^\<\?([=!])\s*(.*?)\s*\?>$/) {
                $flush_pending->();
                if ($1 eq '=') {
                    print $dstfh $push_expr->($2);
                } else {
                    print $dstfh $push_void_expr->($2);
                }
            } elsif ($token ne "") {
                $pending .= $token;
            }
        }
    } else {
        $flush_pending->();
        print $dstfh "$line";
    }
}
$flush_pending->();

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
            # push_void_expr function
            sub {
                my $src = shift;
                return qq{do { $src };};
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
                return qq^{std::string _r; _r += ($src); if (! _r.empty() && *(_r.end() - 1) == '\\n') _r.erase(_r.size() - 1); _ += _r;}^;
            },
            # push_void_expr function
            sub {
                my $src = shift;
                return qq{{std::string::size_type __picotemplate_l = _.size(); { $src; } if (__picotemplate_l != _.size() && *(_.end() - 1) == '\\n') _.erase(_.size() - 1);}};
            },
            # push_str function
            sub {
                my $str = shift;
                $str =~ s/([\\'"])/\\$1/gs;
                $str =~ s/\n/\\n/gs;
                return qq{_ += ("$str");};
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
            # push_void_expr function
            sub {
                my $src = shift;
                return qq{{ $src; }};
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
