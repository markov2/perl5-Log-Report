# This code is part of distribution Log-Report. Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package MojoX::Log::Report;
use Mojo::Base 'Mojo::Log';  # implies use strict etc

use Log::Report 'log-report', import => 'report';

=chapter NAME

MojoX::Log::Report - divert log messages into Log::Report 

=chapter SYNOPSIS

  use MojoX::Log::Report;
  my $log = MojoX::Log::Report->new(%options);
  $app->log($log);  # install logger in the Mojo::App
  
=chapter DESCRIPTION 

[Included since Log::Report v1.00]
Mojo likes to log messages directly into a file, by default.  Log::Report
constructs a M<Log::Report::Exception> object first.

Be aware that this extension does catch the messages to be logged,
but that the dispatching of the error follows a different route now.
For instance, you cannot use C<$ENV{MOJO_LOG_LEVEL}> to control the output
level, but you need to use M<Log::Report::dispatcher()> action C<mode>.

Mojo defines five "levels" of messages, which map onto Log::Report's
reasons this way:

  debug  TRACE
  info   INFO
  warn   WARNING
  error  ERROR
  fatal  ALERT

=chapter METHODS

=section Constructors

=c_method new %options
Inherited %options C<path> and C<level> are ignored.
=cut

sub new(@) {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    # issue with Mojo, where the base-class registers a function --not
    # a method-- to handle the message.
    $self->unsubscribe('message');    # clean all listeners
    $self->on(message => '_message'); # call it OO
    $self;
}

my %level2reason = qw/
 debug  TRACE
 info   INFO
 warn   WARNING
 error  ERROR
 fatal  ALERT
/;

sub _message($$@)
{   my ($self, $level) = (shift, shift);
 
    report +{is_fatal => 0}    # do not die on errors
      , $level2reason{$level}, join('', @_);
}

1;
