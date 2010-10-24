use strict;
use warnings;

use Test::More;
use syntax qw( whilst );

do {
    my @foo   = qw( foo 1 bar 2 baz 3 qux 4 );
    my @pairs = whilst (my $k = shift @foo) { [$k, shift @foo] };

    is_deeply \@pairs, [[foo => 1], [bar => 2], [baz => 3], [qux => 4]], 'pairs';
};

do {
    my $cnt = 10;
    my @nums = whilst ($cnt) { last if $cnt == 3; $cnt-- };
    is_deeply \@nums, [reverse 4..10], 'last';
};

do {
    my $cnt = 10;
    my @nums = whilst ($cnt) { last WHILST if $cnt == 3; $cnt-- };
    is_deeply \@nums, [reverse 4..10], 'last WHILST';
};

do {
    open TEST, '<', \"foo,bar\nbaz,qux\nquux\n";
    my @words = whilst (<TEST>) { chomp; split qr{,} };
    is_deeply \@words, [qw( foo bar baz qux quux )], 'words';
};

do {
    my $foo = 5;
    is scalar(whilst ($foo--) { 23 }), 5, 'scalar context';
};

do {
    my $foo = 10;
    is join(', ', whilst ($foo--) NUM: {
        last NUM if $foo == 5;
        $foo;
    }), '9, 8, 7, 6', 'custom label';
};

done_testing;
