use strict;
use warnings;

# ABSTRACT: A while that returns its results

package Syntax::Feature::Whilst;

use Carp                                qw( croak );
use Params::Classify        0.011       qw( is_ref );
use Devel::Declare          0.006000;
use Sub::Install            0.925       qw( install_sub );
use Data::Dump                          qw( pp );
use B::Hooks::EndOfScope    0.09;

use aliased 'Devel::Declare::Context::Simple', 'Context';

use syntax qw( method );
use namespace::clean;

my $InstallCount = 0;

method import ($class: %args) {

    return $class->install(
        into    => scalar(caller),
        options => \%args,
    );
}

method install ($class: %args) {

    my $target   = $args{into};
    my $options  = $args{options};
    my $name     = 'whilst';
    my $sym_cnt  = 0;
    my $inst_cnt = $InstallCount++;
    my $get_sym  = sub {
        return sprintf '%s__syntax_feature_whilst_lex_%s_%s',
            shift,
            $inst_cnt,
            $sym_cnt++;
    };

    if (is_ref $options, 'HASH') {

        $name = $options->{-as}
            if exists $options->{-as};
    }

    Devel::Declare->setup_for(
        $target => {
            $name => {
                const => sub {
                    my $ctx = Context->new;
                    $ctx->init(@_);
                    return $class->_modify($ctx, $get_sym);
                },
            },
        },
    );

    install_sub {
        into    => $target,
        code    => sub { @_ },
        as      => $name,
    };

    on_scope_end {

        namespace::clean->clean_subroutines(
            $target,
            $name,
        );

        Devel::Declare->teardown_for($target);
    };

    return 1;
}

method _modify ($class: $ctx, $get_sym) {

    $ctx->skip_declarator;
    $ctx->skipspace;

    my $symbol = $get_sym->('@');

    my $condition = $ctx->strip_proto
        or croak sprintf
            q{Expected condition after %s keyword},
            $ctx->declarator;

    my $label = $class->_strip_label($ctx);
    $label = 'WHILST'
        unless defined $label;

    $ctx->inject_if_block(
        $class->_render_block_preamble($symbol),
        $class->_render_block_begin($condition, $symbol, $label),
    ) or croak sprintf
        q{Expected block after %s condition},
        $ctx->declarator;
}

method _strip_label ($class: $ctx) {

    $ctx->skipspace;
    my $linestr = $ctx->get_linestr;
    my $offset  = $ctx->offset;
    my $rest    = substr $linestr, $offset;

    return undef
        unless $rest =~ s{\A ([a-z_][a-z0-9_]*) : }{}xi;

    my $label = $1;

    substr($linestr, $offset) = $rest;
    $ctx->set_linestr($linestr);
    $ctx->skipspace;

    return $label;
}

method _render_block_begin ($class: $condition, $symbol, $label) {

    return sprintf
        q!(do { my %s; %s: while (%s) { push %s, (do !,
        $symbol,
        $label,
        $condition,
        $symbol;
}

method _render_block_end ($class: $symbol) {

    return sprintf
        q!) } %s })!,
        $symbol;
}

method _render_block_preamble ($class: $symbol) {

    return sprintf
        q!BEGIN { %s->%s(%s) };!,
        $class,
        '_inject_block_end',
        pp($symbol);
}

method _inject_block_end ($class: $symbol) {

    on_scope_end {
        my $linestr = Devel::Declare::get_linestr;
        my $offset  = Devel::Declare::get_linestr_offset;
        substr($linestr, $offset, 0) = $class->_render_block_end($symbol);
        Devel::Declare::set_linestr($linestr);
    };
}

1;

__END__

=method install

    ->install(into => $class, options => { -as => $name })
    ->install(into => $class)

Called by L<syntax> and L</import>.

=method import

    ->import(-as => $name)
    ->import()

Allows direct importing of this syntax feature via

    use Syntax::Feature::Whilst;

or under a different name via

    use Syntax::Feature::Whilst -as => 'mapwhile';

This will delegate to L</install> internally.

=cut


=head1 SYNOPSIS

    use strict;
    use warnings;

    use syntax qw( whilst );

    my @list = qw(
        foo 1
        bar 2
        baz 3
    );

    my @pairs = whilst (my $k = shift @list) {
        [ $k, shift @list ];
    };

=head1 DESCRIPTION

This syntax extension implements a C<whilst> keyword that loops via a condition
like C<while>, but will return a list of its values. The basic keyword syntax
is as follows:

    whilst (<condition>) <block>

The C<condition> is the same kind you would use in a C<while> statement. The
C<block> is a normal Perl block that will be called in list context. As usual
with C<while> blocks, all lexicals declared in the C<condition> will be
available inside the C<block>.

This syntax extension acts as an expression. Which means that you will have to
terminate the statement with a semicolon (C<;>) manually, but you can insert
C<whilst> expression in other statements and expressions.

You can use C<next>, C<last> and C<redo> as usual within while loops. The loop
constructed by C<whilst> will have an implicit C<WHILST> label. You can also set a
custom label. Since this keyword can be used as an expression, the label has
to be attached to the block instead of the keyword:

    whilst (<condition>) <label>: <block>

Or to put it into a Perl example:

    my @counts = whilst ($count--) COUNT: {

        last COUNT
            if $count < $limit;

        $count;
    };

Below are some more L<examples|/EXAMPLES> detailing the syntax.

=head1 EXAMPLES

=head2 I/O

    my @words = whilst (<>) { chomp; split /,/ };

=head2 Loop Modifiers

    my @properties = whilst (defined( my $line = shift @lines )) {

        last unless length($line)
                 or length($lines[0]);

        next unless length($line);

        [ split qr{\s*:\s*}, $line, 2 ];
    };

=head2 Nested Loops

    my @accepted = whilst (my $next = @todo) {

        for $excluded (qw( foo bar baz )) {
            next WHILST if $next eq $test;
        }

        $next;
    };

=head1 SEE ALSO

L<syntax>,
L<Devel::Declare>,
L<perlfunc/while>,
L<perlfunc/map>

=cut
