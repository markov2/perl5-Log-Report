#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Log::Report::Dispatcher::Callback;
use base 'Log::Report::Dispatcher';

use warnings;
use strict;

use Log::Report 'log-report';

#--------------------
=chapter NAME
Log::Report::Dispatcher::Callback - call a code-ref for each log-line

=chapter SYNOPSIS

  sub cb($$$)
  {   my ($disp, $options, $reason, $message) = @_;
      ...
  }

  dispatcher Log::Report::Dispatcher::Callback => 'cb',
        callback => \&cb;

  dispatcher CALLBACK => 'cb',   # same
        callback => \&cb;

=chapter DESCRIPTION
This basic file logger accepts a callback, which is called for each
message which is to be logged. When you need complex things, you
may best make your own extension to Log::Report::Dispatcher, but
for simple things this will do.

=example
  sub send_mail($$$)
  {   my ($disp, $options, $reason, $message) = @_;
      my $msg = Mail::Send->new(Subject => $reason, To => 'admin@localhost');
      my $fh  = $msg->open('sendmail');
      print $fh $disp->translate($reason, $message);
      close $fh;
  }

  dispatcher CALLBACK => 'mail', callback => \&send_mail;

=chapter METHODS

=section Constructors

=c_method new $type, $name, %options

=requires callback CODE
Your P<callback> is called with five parameters: this dispatcher object,
the options, a reason and a message.  The C<options> are the first
parameter of M<Log::Report::report()> (read over there).  The C<reason>
is a capitized string like C<ERROR>. Then, the C<message> (is a
Log::Report::Message).  Finally the text-domain of the message.

=cut

=error dispatcher $name needs a 'callback'
=cut

sub init($)
{	my ($self, $args) = @_;
	$self->SUPER::init($args);

	$self->{callback} = $args->{callback}
		or error __x"dispatcher {name} needs a 'callback'", name => $self->name;

	$self;
}

#--------------------
=section Accessors

=method callback
Returns the code reference which will handle each logged message.
=cut

sub callback() { $_[0]->{callback} }

#--------------------
=section Logging
=cut

sub log($$$$)
{	my $self = shift;
	$self->{callback}->($self, @_);
}

1;
