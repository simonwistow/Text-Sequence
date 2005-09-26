package Text::Sequence;

use strict;
use Carp;
use vars qw($VERSION);

$VERSION = '0.22';

=pod

=head1 NAME

Text::Sequence - spot one-dimensional sequences in patterns of text

=head1 SYNOPSIS

    use Text::Sequence;
    
    my @list      = get_files_in_dir();
    my @sequences = Text::Sequence::find(@list);

    my $sequence  = @sequences[0];
    print $sequence->template();

    my $num = 0;    
    foreach my ($element) ($sequence->members()) {
        ++$num;
        print "$num) $filename\n";
    }
    
=head1 DESCRIPTION

A sequence could be a list of files like

    00001.jpg
    00002.jpg
    00003.jpg
    ...
    05000.jpg
    
    
or

    raw.0001.txt
    ...
    raw.0093.txt

or

    foo3a.html
    foo3b.html
    foo3c.html

or even

    1.mp3
    100.mp3
    
in which case their templates would be

    %.5d.tif
    
    raw.%.4d.txt

    foo3%s.html
    
    %d.mp3
    
respectively.   
    
This library will attempt to 

=over 4 

=item find all sequences in a given list

=item tell you which elements are missing from a sequence

=item be able to cope with non padded numbers in sequences

=back

It does B<not> spot multi-dimensional sequences, e.g. C<foo-%d-%d.jpg>.

=head1 METHODS


=head2 find( @elements )

A static method to find all the sequences in a list of elements.

=cut

sub find {
    my %candidates;

    foreach my $element (@_) {
        next unless $element =~ /\d/; # nothing without numbers

        while ($element =~ /\G.*?(?:(\d+)|(?<![a-z])([a-z])\b)/gi) {
            my $cand = $element;

            if ($1) {
              # Numerical sequence
              my $num = substr($cand, $-[1], $+[1] - $-[1], '%d');
              
              # There could be multiple lengths of the number we just
              # changed to a %d, need to analyse the length frequencies
              # in conjunction with the padding to see if differing
              # lengths are still part of the same sequence (e.g.
              # to distinguish foo.%3d.bar from foo.%02d.bar).
              my $length = length($num);
              # Note that a single zero is not counted as padded.
              my $pad = ($num =~ /^0\d/) ? 'p' : '';
              # Note how we "de-pad" the members here.
              push @{ $candidates{$cand}{formats}{$pad . $length} }, $num + 0;
              $candidates{$cand}{count}++;
            }
            elsif ($2) {
              my $letter = substr($cand, $-[2], $+[2] - $-[2], '%s');
              push @{ $candidates{$cand}{formats}{letter} }, $letter;
              $candidates{$cand}{count}++;
            }
            else {
              die "BUG!";
            }
        }
    }

    my @seqs;

    foreach my $cand (keys %candidates) {
        # it's not a sequence if there's only 1
        next if $candidates{$cand}{count} == 1; 

        my $formats = $candidates{$cand}{formats};

        if (my $letters = $formats->{letter}) {
          push @seqs, Text::Sequence->new($cand, @$letters);
          next;
        }

        # That was the easy bit, numbers are much harder.

        # First look for padded numbers.  Padding is quite a
        # deliberate action, so our best effort assumption is that if
        # there is a number padded to length n, any other (non-padded)
        # numbers of length n must belong to the same sequence.  It's
        # not quite optimal, but we'd need some serious AI to separate
        # things like (1, 4, 64, 256, 07 .. 13) into
        # 
        #   [ map 4**$_, 0 .. 3 ] and [ 07 .. 13 ]
        #
        # The following code will separate it into
        #
        #   [ 07 .. 13, 64 ] and [ 1, 4, 256 ]
        #
        foreach my $padded (grep /^p/, keys %$formats) {
            (my $length = $padded) =~ s/^p//;
            my @members = (
                @{ $formats->{$padded}       },
                @{ $formats->{$length} || [] },
            );
            delete @$formats{$padded, $length};
            (my $pcand = $cand) =~ s/%d/%.${length}d/;
            push @seqs, Text::Sequence->new($pcand, @members);
        }
        # Now the remaining elements (if any) all get swept into the
        # %d non-padded bucket.
        my @members = ( map @{ $formats->{$_} }, keys %$formats );
        push @seqs, Text::Sequence->new($cand, @members) if @members;
    }

    return @seqs; 
}


=head2 new( $template, @member_nums )

Creates a new sequence object.

=cut

sub new {
    my $class   = shift;
    my $template = shift or die "You must pass a template\n";

    my $self = bless {
        template => $template,
        members  => [ @_ ],
    }, $class;

    return $self;
}

=head2 template( $number_or_letter )

Tell you the template of the sequence, in C<printf>-like formats.

If you pass in a number or letter then it will substitute it in to
return an actual sequence element.

=cut

sub template {
    my $self = shift;
    
    if (@_) {
        return sprintf($self->{template}, $_[0]);
    } else {
        return $self->{template};
    }
}

=head2 members()

Returns a list describing the members of the sequence.  Each item in
the list is a letter or (non-padded) number which can be substituted
into the template to obtain the original element

For members of the same width, order is preserved from the original
call to C<find()>.

=cut

sub members {
    my $self = shift;
    return @{ $self->{members} };
}

=head1 AUTHOR

Simon Wistow <simon@thegestalt.org>
Adam Spiers <cpan@adamspiers.org>

=head1 COPYRIGHT

Copyright (c) 2004 - Simon Wistow

=head1 BUGS

=head1 SEE ALSO

=cut

1;
