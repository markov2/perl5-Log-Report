use warnings;
use strict;

package Log::Report::Exception;

use Log::Report 'log-report';
use POSIX  qw/locale_h/;

=chapter NAME
Log::Report::Exception - a collected report

=chapter SYNOPSIS
 # created within a try block
 try { error "help!" };
 my $exception = $@->wasFatal;
 $exception->throw if $exception;

 $@->reportFatal;  # combination of above two lines

=chapter DESCRIPTION
In Log::Report, exceptions are not as extended as available in
languages as Java: you do not create classes for them.  The only
thing an exception object does, is capture some information about
an (untranslated) report.

=chapter OVERLOADING

=chapter METHODS

=section Constructors
=c_method new OPTIONS, VARIABLES

=option  report_opts HASH
=default report_opts {}

=requires reason REASON
=requires message Log::Report::Message
=cut

sub new($@)
{   my ($class, %args) = @_;
    $args{report_opts} ||= {};
    bless \%args, $class;
}

=section Accessors

=method report_opts
=method reason
=method message
=cut

sub report_opts() {shift->{report_opts}}
sub reason()      {shift->{reason}}
sub message()     {shift->{message}}

=section Reporting Exceptions

=method throw OPTIONS
Insert the message contained in the exception into the currently
defined dispatchers.  The C<throw> name is commonly known
exception related terminology for C<report>.
=cut

# if we would used "report" here, we get a naming conflict with
# function Log::Report::report.
sub throw(@)
{   my $self = shift;
    report $self->{report_opts}, $self->reason, $self->message;
}

1;
