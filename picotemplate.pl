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

my $srcfn = shift @ARGV;
die "no filename"
    unless $srcfn;

my ($push_expr, $push_void_expr, $push_str) = convfunc($srcfn);

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
        for my $token (split /(<\?[=!].*?\?>)/, $markup) {
            if ($token =~ /^\<\?([=!])\s*(.*?)\s*\?>$/) {
                if ($1 eq '=') {
                    push @st, $push_expr->($2);
                } else {
                    push @st, $push_void_expr->($2);
                }
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
