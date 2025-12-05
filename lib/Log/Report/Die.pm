#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Log::Report::Die;
use base 'Exporter';

use warnings;
use strict;

our @EXPORT = qw/die_decode exception_decode/;

use POSIX  qw/locale_h/;

#--------------------
=chapter NAME
Log::Report::Die - compatibility routines with Perl's die/croak/confess

=chapter SYNOPSIS
  # use internally only

=chapter DESCRIPTION

This module is used internally, to translate output of 'die' and Carp
functions into Log::Report::Message objects.  Also, it tries to
convert other kinds of exception frameworks into our message object.

=chapter FUNCTIONS

=function die_decode STRING, %options
The STRING is the content of C<$@> after an eval() caught a die().
croak(), or confess().  This routine tries to convert this into
parameters for M<Log::Report::report()>.  This is done in a very
smart way, even trying to find the stringifications of C<$!>.

Returned are four elements: the error string or object which triggered
the death originally (the original $@), and the opts, reason, and plain
text message.  The opts is a HASH which, amongst other things, may contain
a stack trace and location extracted from the death text or object.

Translated components will have exception classes C<perl>, and C<die> or
C<confess>.  On the moment, the C<croak> cannot be distiguished from the
C<confess> (when used in package main) or C<die> (otherwise).

The returned reason depends on whether the translation of the current
C<$!> is found in the STRING, and the presence of a stack trace.  The
following table is used:

  errstr  stack  =>  reason
    no      no       ERROR   (die) application internal problem
    yes     no       FAULT   (die) external problem, think open()
    no      yes      PANIC   (confess) implementation error
    yes     yes      ALERT   (confess) external problem, caught

=option  on_die REASON
=default on_die 'ERROR'
=cut

sub die_decode($%)
{	my ($text, %args) = @_;

	my @text   = split /\n/, $text;
	@text or return ();
	chomp $text[-1];

	# Try to catch the error directly, to remove it from the error text
	my %opt    = (errno => $! + 0);
	my $err    = "$!";

	if($text[0] =~ s/ at (.+) line (\d+)\.?$// )
	{	$opt{location} = [undef, $1, $2, undef];
	}
	elsif(@text > 1 && $text[1] =~ m/^\s*at (.+) line (\d+)\.?$/ )
	{	# sometimes people carp/confess with \n, folding the line
		$opt{location} = [undef, $1, $2, undef];
		splice @text, 1, 1;
	}

	$text[0] =~ s/\s*[.:;]?\s*$err\s*$//  # the $err is translation sensitive
		or delete $opt{errno};

	my @msg = shift @text;
	length $msg[0] or $msg[0] = 'stopped';

	my @stack;
	foreach (@text)
	{	if(m/^\s*(.*?)\s+called at (.*?) line (\d+)\s*$/)
		     { push @stack, [ $1, $2, $3 ] }
		else { push @msg, $_ }
	}
	$opt{stack}   = \@stack;
	$opt{classes} = [ 'perl', (@stack ? 'confess' : 'die') ];

	my $reason
	  = $opt{errno} ? 'FAULT'
	  : @stack      ? 'PANIC'
	  :               $args{on_die} || 'ERROR';

	(\%opt, $reason, join("\n", @msg), 'die');
}

=function exception_decode $exception, %options
[1.23] This function attempts to translate object of other exception frameworks
into information to create a Log::Report::Exception.  It returns the
same list of parameters as M<die_decode()> does.

Currently supported:
=over 4
=item * DBIx::Class::Exception
=item * XML::LibXML::Error
=back
=cut

sub _exception_dbix($$)
{	my ($exception, $args) = @_;
	my $on_die = delete $args->{on_die};
	my %opts   = %$args;

	my @lines  = split /\n/, "$exception";  # accessor missing to get msg
	my $first  = shift @lines;
	my ($sub, $message, $fn, $linenr) = $first =~
		m/^ (?: ([\w:]+?) \(\)\: [ ] | \{UNKNOWN\}\: [ ] )?
			(.*?)
			\s+ at [ ] (.+) [ ] line [ ] ([0-9]+)\.?
		$/x;
	my $pkg    = defined $sub && $sub =~ s/^([\w:]+)\:\:// ? $1 : $0;

	$opts{location} ||= [ $pkg, $fn, $linenr, $sub ];

	my @stack;
	foreach (@lines)
	{	my ($func, $fn, $linenr) = /^\s+(.*?)\(\)\s+called at (.*?) line ([0-9]+)$/ or next;
		push @stack, [ $func, $fn, $linenr ];
	}
	$opts{stack} ||= \@stack if @stack;

	my $reason
	  = $opts{errno} ? 'FAULT'
	  : @stack       ? 'PANIC'
	  :                $on_die || 'ERROR';

	(\%opts, $reason, $message, 'exception, dbix');
}

my %_libxml_errno2reason = (1 => 'WARNING', 2 => 'MISTAKE', 3 => 'ERROR');

sub _exception_libxml($$)
{	my ($exc, $args) = @_;
	my $on_die = delete $args->{on_die};
	my %opts   = %$args;

	$opts{errno}    ||= $exc->code + 13000;
	$opts{location} ||= [ 'libxml', $exc->file, $exc->line, $exc->domain ];

	my $msg = $exc->message . $exc->context . "\n"
			. (' ' x $exc->column) . '^'
			. ' (' . $exc->domain . ' error ' . $exc->code . ')';

	my $reason = $_libxml_errno2reason{$exc->level} || 'PANIC';
	(\%opts, $reason, $msg, 'exception, libxml');
}

sub exception_decode($%)
{	my ($exception, %args) = @_;
	my $errno = $! + 0;

	return _exception_dbix($exception, \%args)
		if $exception->isa('DBIx::Class::Exception');

	return _exception_libxml($exception, \%args)
		if $exception->isa('XML::LibXML::Error');

	# Unsupported exception system, sane guesses
	my %opt = (
		classes => [ 'unknown exception', 'die', ref $exception ],
		errno   => $errno,
	);

	my $reason = $errno ? 'FAULT' : ($args{on_die} || 'ERROR');

	# hopefully stringification is overloaded
	(\%opt, $reason, "$exception", 'exception');
}

"to die or not to die, that's the question";
