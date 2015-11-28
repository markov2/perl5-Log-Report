package Dancer2::Plugin::LogReport;

use warnings;
use strict;

use Dancer2::Plugin;
use Dancer2::Plugin::LogReport::Message;
use Log::Report  'log-report', syntax => 'REPORT',
    message_class => 'Dancer2::Plugin::LogReport::Message';

use Scalar::Util qw/blessed/;

my $_dsl;        # XXX How to avoid the global?   Dancer2::Core::DSL
my $_settings;

=chapter NAME

Dancer2::Plugin::LogReport - logging and exceptions via Log::Report

=chapter SYNOPSIS

  # Load the plugin into Dancer2
  # see Log::Report::import() for %options
  use Log::Report ();    # load early in main
  use Dancer2::Plugin::LogReport %options;

  # Stop execution, redirect, and display an error to the user
  $name or error "Please enter a name";

  # Add debug information to logger
  trace "We're here";

  # Handling user errors cleanly
  if (process( sub {MyApp::Model->create_user} )) {
      # Success, redirect user elsewhere
  } else {
      # Failed, continue as if submit hadn't been made.
      # Error message will be in session for display later.
  }

  # Send errors to template for display
  hook before_template => sub {
      my $tokens = shift;
      $tokens->{messages} = session 'messages';
      session 'messages' => [];
  }

=chapter DESCRIPTION

[The Dancer2 plugin was contributed by Andrew Beverley]

This module provides easy access to the extensive logging facilities
provided by M<Log::Report>. Along with M<Dancer2::Logger::LogReport>,
this brings together all the internal Dancer2 logging, handling for
expected and unexpected exceptions, translations and application logging.

Logging is extremely flexible using many of the available
L<dispatchers|Log::Report::Dispatcher/DETAILS>.  Multiple dispatchers can be
used, each configured separately to display different messages in different
formats.  By default, messages are logged to a session variable for display on
a webpage, and to STDERR.

Messages within this plugin use the extended
L<Dancer2::Logger::LogReport::Message> class rather than the standard
L<Log::Report::Message> class.

Read the L</DETAILS> in below in this manual-page.

=chapter METHODS

=cut

# "use" import
sub import
{   my $class = shift;
    Log::Report->import('+2', @_, syntax => 'LONG');
}

my %session_messages;
# The default reasons that a message will be displayed to the end user
my @default_reasons = qw/NOTICE WARNING MISTAKE ERROR FAULT ALERT FAILURE PANIC/;
my $hide_real_message; # Used to hide the real message to the end user
my $messages_variable = $_settings->{messages_key} || 'messages';


# Dancer2 import
on_plugin_import
{   my $dsl      = $_dsl      = shift;  # capture global singleton
    my $settings = $_settings = plugin_setting;

    # Need init_error for exceptions and other errors
    $dsl->hook(init_error => sub {
        my $error = shift;
        # Catch other exceptions. This hook is called for all errors
        # not just exceptions (including for example 404s), so check first.
        # If it's an exception then panic it to get Log::Report
        # to handle it nicely. If it's another error such as a 404
        # then exception will not be set.
        report 'PANIC' => $error->{exception}
            if $error->{exception};
    });

    if($settings->{handle_http_errors})
    {   # Need after_error for HTTP errors (eg 404) so as to
        # be able to change the forwarding location
        $dsl->hook(after_error => sub {
            my $error = shift;
            my $msg = __($error->status . ": "
              . Dancer2::Core::HTTP->status_message($error->status));

            # XXX This doesn't work at the moment. The DSL at this point
            # doesn't seem to respond to changes in the session or
            # forward requests
            _forward_home( $_dsl, $msg );
        });
    }

    $dsl->hook(after_layout_render => sub {
        my $session = $_dsl->app->session;
        $session->write($messages_variable => []);
    });

    # Define which messages are saved to the session for later display
    # to the user. This can be configured in the config file, or we
    # choose some sensible defaults.
    my $sm = $settings->{session_messages} // \@default_reasons;
    $session_messages{$_} = 1
        for ref $sm eq 'ARRAY' ? @$sm : $sm;

    # In a production server, we don't want the end user seeing (unexpected)
    # exception messages, for both security and usability. If we detect
    # that this is a production server (show_errors is 0), then we change
    # the specific error to a generic error, when displayed to the user.
    # The message can be customised in the config file.
    my $fatal_error_message = $settings->{fatal_error_message}
        || "An unexpected error has occurred";
    unless($dsl->app->config->{show_errors})
    {   $hide_real_message->{$_} = $fatal_error_message for qw/FAULT ALERT FAILURE PANIC/;
    }

    # This is so that all messages go into the session, to be displayed
    # on the web page (if required)
    dispatcher CALLBACK => 'error_handler'
      , callback => \&_error_handler
      , mode     => 'DEBUG';
};    # ";" required!

=method process

C<process()> is an eval, but one which expects and handles exceptions
generated by M<Log::Report>. Any messages will be logged as normal in
accordance with the dispatchers, but any fatal exceptions will be caught
and handled gracefully.  This allows much simpler error handling, rather
than needing to test for lots of different scenarios.

In a module, it is enough to simply use the C<error> keyword in the event of a
fatal error.

The return value will be 1 for success or 0 if a fatal exception occurred.

See the L</DETAILS> for an example of how this is expected to be used.

Modules do not need to use this plugin, instead they can C<use Log::Report>.

=cut

sub process($$)
{   my ($dsl, $coderef) = @_;
    try { $coderef->() } hide => 'ALL';
    my $success = $@->died ? 0 : 1;
    $@->reportAll(is_fatal => 0);
    $success;
}

register process => \&process;

sub _message_add($)
{   my $msg = shift;

    return
        if ! $session_messages{$msg->reason}
        ||   $msg->inClass('no_session');

    my $app = $_dsl->app;
    unless($app->request)
    {   # This happens for HTTP errors
        # XXX the session is not available in the DSL
        report 'ASSERT' => "Unable to write message to session: unable to write cookie";
        return;
    }

    my $r = $msg->reason;
    if(my $newm = $hide_real_message->{$r})
    {   $msg    = __$newm;
        $msg->reason($r);
    }

    my $session = $app->session;
    my $msgs    = $session->read($messages_variable);
    push @$msgs, $msg;
    $session->write($messages_variable => $msgs);
}

#------
=section Handlers

All the standard M<Log::Report> functions are available to use. Please see the
L<Log::Report/"The Reason for the report"> for details
of when each one should be used.

L<Log::Report class functionality|Log::Report::Message.pod#class-STRING-ARRAY>
to class messages (which can then be tested later):

  notice __x"Class me up", _class => 'label';
  ...
  if ($msg->inClass('label')) ...

M<Dancer2::Plugin::LogReport> has a special message class, C<no_session>,
which prevents the message from being saved to the messages session
variable. This is useful, for example, if you are writing messages within
the session hooks, in which case recursive loops can be experienced.

=method trace
=method assert
=method info
=method notice
=method warning
=method mistake
=method error
=method fault
=method alert
=method failure
=method panic
=cut

sub _forward_home($$)
{   my $dsl = shift;
    _message_add(shift);
    my $page = $_settings->{forward_url} || '/';
    $dsl->redirect($page);
}

sub _error_handler($$$$)
{   my ($disp, $options, $reason, $message) = @_;

    my $fatal_handler = sub {
        my $req = $_dsl->request;
        _forward_home( $_dsl, $_[0] )
            if $req && ($req->uri ne '/' || !$req->is_get);
    };

    $message->reason($reason);

    my %handler =
      ( # Default do nothing for the moment (TRACE|ASSERT|INFO)
        default => sub {_message_add $_[0]}

        # A user-created error condition that is not recoverable.
        # This could have already been caught by the process
        # subroutine, in which case we should continue running
        # of the program. In all other cases, we should bail
        # out. With the former, the exception will have been
        # re-thrown as a non-fatal exception, so check that.
      , ERROR   => sub {
            return _message_add( $_[0] )
                if exists $options->{is_fatal} && !$options->{is_fatal};

            my $req = $_dsl->request;
            return  _forward_home( $_dsl, $_[0] )
                if $req && ($req->uri ne '/' || !$req->is_get);

            return;
       }

        # 'FAULT', 'ALERT', 'FAILURE', 'PANIC'
        # All these are fatal errors. Display error to user, but
        # forward home so that we can reload. However, don't if
        # it's a GET request to the home, as it will cause a recursive
        # loop. In this case, do nothing, and let dancer handle it.
      , FAULT   => $fatal_handler
      , ALERT   => $fatal_handler
      , FAILURE => $fatal_handler
      , PANIC   => $fatal_handler
      );

    my $call = $handler{$reason} || $handler{default};
    $call->($message);
}

sub _report($@) {
    my ($reason, $dsl) = (shift, shift);

    my $msg = (blessed($_[0]) && $_[0]->isa('Log::Report::Message'))
       ? $_[0] : Dancer2::Core::Role::Logger::_serialize(@_);

    if ($reason eq 'SUCCESS')
    {
        $msg = __$msg unless blessed $msg;
        $msg = $msg->clone(_class => 'success');
        $reason = 'NOTICE';
    }
    report uc($reason) => $msg;
}

register trace   => sub { _report(TRACE => @_) };
register assert  => sub { _report(ASSERT => @_) };
register notice  => sub { _report(NOTICE => @_) };
register mistake => sub { _report(MISTAKE => @_) };
register panic   => sub { _report(PANIC => @_) };
register alert   => sub { _report(ALERT => @_) };

=method success
This is a special additional type, equivalent to C<notice>.  The difference is
that messages using this keyword will have the class C<success> added, which
can be used to color the messages differently to the end user. For example,
L<Dancer2::Plugin::LogReport::Message#bootstrap_color> uses this to display the
message in green.
=cut
register success => sub { _report(SUCCESS => @_) };

register_plugin for_versions => ['2'];

#----------

=chapter CONFIGURATION

All configuration is optional. The example configuration file below shows the
configuration options and defaults.

    plugins:
      LogReport:
        # Whether to handle Dancer HTTP errors such as 404s. Currently has
        # no effect due to unresolved issues saving messages to the session
        # and accessing the DSL at that time.
        handle_http_errors: 1
        # For a production server (show_errors: 0), this is the text that
        # will be displayed instead of unexpected exception errors
        fatal_error_message: An unexpected error has occurred
        # The levels of messages that will be saved to the session, and
        # thus displayed to the end user
        session_messages: [ NOTICE WARNING MISTAKE ERROR FAULT ALERT FAILURE PANIC ]

=chapter DETAILS

This chapter will guide you through the myriad of ways that you can use
M<Log::Report> in your Dancer2 application.

We will set up our application to do the following:

=over 4

=item Messages to the user
We'll look at an easy way to output messages to the user's web page, whether
they be informational messages, warnings or errors.

=item Debug information
We'll look at an easy way to log debug information, at different levels.

=item Manage unexpected exceptions
We'll handle unexpected exceptions cleanly, in the unfortunate event that
they happen in your production application.

=item Email alerts of significant errors
If we do get unexpected errors then we want to be notified them.

=item Log DBIC information and errors
We'll specifically look at nice ways to log SQL queries and errors when
using DBIx::Class.

=back

=section Larger example

In its simplest form, this module can be used for more flexible logging

  get '/route' => sub {
      # Stop execution, redirect, and display an error to the user
      $name or error "Please enter a name";
 
      # The same but translated
      $name or error __"Please enter a name";
  
      # The same but translated and with variables
      $name or error __x"{name} is not valid", name => $name;
 
      # Show the user a warning, but continue execution
      mistake "Not sure that's what you wanted";
 
      # Add debug information, can be caught in syslog by adding
      # the (for instance) syslog dispatcher
      trace "Hello world";
   };

=section Setup and Configuration

To make full use of L<Log::Report>, you'll need to use both
L<Dancer2::Logger::LogReport> and L<Dancer2::Plugin::LogReport>.

=subsection Dancer2::Logger::LogReport

Set up L<Dancer2::Logger::LogReport> by adding it to your Dancer2
application configuration (see L<Dancer2::Config>). By default,
all messages will go to STDERR.

To get all message out "the Perl way" (using print, warn and die) just use

  logger: "LogReport"

At start, these are handled by a M<Log::Report::Dispatcher::Perl> object,
named 'default'.  If you open a new dispatcher with the name 'default',
the output via the perl mechanisms will be stopped.

To also send messages to your syslog:

  logger: "LogReport"

  engines:
    logger:
      LogReport:
        log_format: %a%i%m
        app_name: MyApp
        dispatchers:
          default:              # Name
            type: SYSLOG        # Log::Reporter::dispatcher() options
            identity: myapp
            facility: local0
            flags: "pid ndelay nowait"
            mode: DEBUG

To send messages to a file:

  logger: "LogReport"

  engines:
    logger:
      LogReport:
        log_format: %a%i%m
        app_name: MyApp
        dispatchers:
          logfile:              # "default" dispatcher stays open as well
            type: FILE
            to: /var/log/myapp.log
            charset: utf-8
            mode: DEBUG

See L<Log::Report::Dispatcher> for full details of options.

Finally: a Dancer2 script may run many applications.  Each application
can have its own logger configuration.  However, Log::Report dispatchers
are global, so will be shared between Dancer2 applications.  Any attempt
to create a new Log::Report dispatcher by the same name (as will happen
when a new Dancer2 application is started with the same configuration)
will be ignored.

=subsection Dancer2::Plugin::LogReport

To use the plugin, you simply use it in your application:

  package MyApp;
  use Log::Report ();  # use early and minimal once
  use Dancer2;
  use Dancer2::Plugin::LogReport %config;

Dancer2::Plugin::LogReport takes the same C<%config> options as
L<Log::Report> itself (see M<Log::Report::import()>).

If you want to send messages from your modules/models, there is
no need to use this specific plugin. Instead, you should simply
C<use Log::Report> to negate the need of loading all the Dancer2
specific code.

=section In use

=subsection Logging debug information

In its simplest form, you can now use all the
L<Log::Report logging functions|Log::Report#The-Reason-for-the-report>
to send messages to your dispatchers (as configured in the Logger
configuration):

  trace "I'm here";

  warning "Something dodgy happened";

  panic "I'm bailing out";

  # Additional, special Dancer2 keyword
  success "Settings saved successfully";

=subsection Exceptions

Log::Report is a combination of a logger and an exception system.  Messages
to be logged are I<thrown> to all listening dispatchers to be handled.

This module will also catch any unexpected exceptions:

  # This will be caught, the error will be logged (full stacktrace to STDOUT,
  # short message to the session messages), and the user will be forwarded
  # (default to /). This would also be sent to syslog with the appropriate
  # dispatcher.
  get 'route' => sub {
      my $foo = 1;
      my $bar = $foo->{x}; # whoops
  }

For a production application (C<show_errors: 1>), the message saved in the
session will be the generic text "An unexpected error has occurred". This
can be customised in the configuration file, and will be translated.

=subsection Sending messages to the user

To make it easier to send messages to your users, messages at the following
levels are also stored in the user's session: C<notice>, C<warning>, C<mistake>,
C<error>, C<fault>, C<alert>, C<failure> and C<panic>.

You can pass these to your template and display them at each page render:

  hook before_template => sub {
    my $tokens = shift;
    $tokens->{messages} = session 'messages';
    session 'messages' => []; # Clear the message queue
  }

Then in your template (for example the main layout):

  [% FOR message IN messages %]
    <div class="alert alert-[% message.bootstrap_color %]">
      [% message.toString | html_entity %]
    </div>
  [% END %]

The C<bootstrap_color> of the message is compatible with Bootstrap contextual
colors: C<success>, C<info>, C<warning> or C<danger>.

Now, anywhere in your application that you have used Log::Report, you can

  warning "Hey user, you should now about this";

and the message will be sent to the next page the user sees.

=subsection Handling user errors

Sometimes we write a function in a model, and it would be nice to have a
nice easy way to return from the function with an error message. One
way of doing this is with a separate error message variable, but that
can be messy code. An alternative is to use exceptions, but these
can be a pain to deal with in terms of catching them.
Here's how to do it with Log::Report.

In this example, we do use exceptions, but in a neat, easier to use manner.

First, your module/model:

  package MyApp::CD;

  sub update {
    my ($self, %values) = @_;
    $values{title} or error "Please enter a title";
    $values{description} or warning "No description entered";
  }

Then, in your controller:

  package MyApp;
  use Dancer2;

  post '/cd' => sub {
    my %values = (
      title       => param('title');
      description => param('description');
    );
    if (process sub { MyApp::CD->update(%values) } ) {
      success "CD updated successfully";
      redirect '/cd';
    }

    template 'cd' => { values => \%values };
  }

Now, when update() is called, any exceptions are caught. However, there is
no need to worry about any error messages. Both the error and warning
messages in the above code will have been stored in the messages session
variable, where they can be displayed using the code in the previous section.
The C<error> will have caused the code to stop running, and process()
will have returned false. C<warning> will have simply logged the warning
and not caused the function to stop running.

=subsection Logging DBIC database queries and errors

If you use L<DBIx::Class> in your application, you can easily integrate
its logging and exceptions. To log SQL queries:

  # Log all queries and execution time
  $schema->storage->debugobj(new Log::Report::DBIC::Profiler);
  $schema->storage->debug(1);

By default, exceptions from DBIC are classified at the level "error". This
is normally a user level error, and thus may be filtered as normal program
operation. If you do not expect to receive any DBIC exceptions, then it
is better to class them at the level "panic":

  # panic() DBIC errors
  $schema->exception_action(sub { panic @_ });
  # Optionally get a stracktrace too
  $schema->stacktrace(1);

If you are occasionally running queries where you expect to naturally
get exceptions (such as not inserting multiple values on a unique constraint),
then you can catch these separately:

  try { $self->schema->resultset('Unique')->create() };
  # Log any messages from try block, but only as trace
  $@->reportAll(reason => 'TRACE');

=subsection Email alerts of exceptions

If you have an unexpected exception in your production application,
then you probably want to be notified about it. One way to do so is
configure rsyslog to send emails of messages at the panic level. Use
the following configuration to do so:

  # Normal logging from LOCAL0
  local0.*                        -/var/log/myapp.log

  # Load the mail module
  $ModLoad ommail
  # Configure sender, receiver and mail server
  $ActionMailSMTPServer localhost
  $ActionMailFrom root
  $ActionMailTo root
  # Set up an email template
  $template mailSubject,"Critical error on %hostname%"
  $template mailBody,"RSYSLOG Alert\r\nmsg='%msg%'\r\nseverity='%syslogseverity-text%'"
  $ActionMailSubject mailSubject
  # Send an email no more frequently than every minute
  $ActionExecOnlyOnceEveryInterval 60
  # Configure the level of message to notify via email
  if $syslogfacility-text == 'local0' and $syslogseverity < 3 then :ommail:;mailBody
  $ActionExecOnlyOnceEveryInterval 0

With the above configuration, you will only be emailed of severe errors, but can
view the full log information in /var/log/myapp.log


=cut

1;

