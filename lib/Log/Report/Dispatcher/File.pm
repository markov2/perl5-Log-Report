use warnings;
use strict;

package Log::Report::Dispatcher::File;
use base 'Log::Report::Dispatcher';

use Log::Report  'log-report';
use IO::File     ();
use POSIX        qw/strftime/;

use Encode       qw/find_encoding/;
use Fcntl        qw/:flock/;

=chapter NAME
Log::Report::Dispatcher::File - send messages to a file or file-handle

=chapter SYNOPSIS
 dispatcher Log::Report::Dispatcher::File => 'stderr'
   , to => \*STDERR, accept => 'NOTICE-';

 # close a dispatcher
 dispatcher close => 'stderr';

 # let dispatcher open and close the file
 dispatcher FILE => 'mylog', to => '/var/log/mylog'
   , charset => 'utf-8';
 ...
 dispatcher close => 'mylog';  # will close file

 # open yourself, then also close yourself
 open OUT, ">:encoding('iso-8859-1')", '/var/log/mylog'
     or fault "...";
 dispatcher FILE => 'mylog', to => \*OUT;
 ...
 dispatcher close => 'mylog';  
 close OUT;

 # dispatch into a scalar
 my $output = '';
 open $outfile, '>', \$output;
 dispatcher FILE => 'into-scalar', to => \$outfile;
 ...
 dispatcher close => 'into-scalar';
 print $output;

=chapter DESCRIPTION
This basic file logger accepts an file-handle or filename as destination.

[1.00] writing to the file protected by a lock, so multiple processes
can write to the same file.

=chapter METHODS

=section Constructors

=c_method new $type, $name, %options

=requires to FILENAME|FILEHANDLE|OBJECT
You can either specify a FILENAME, which is opened in append mode with
autoflush on. Or pass any kind of FILE-HANDLE or some OBJECT which
implements a C<print()> method. You probably want to have autoflush
enabled on your FILE-HANDLES.

When cleaning-up the dispatcher, the file will only be closed in case
of a FILENAME.

=option  replace BOOLEAN
=default replace C<false>
Only used in combination with a FILENAME: throw away the old file
if it exists.  Probably you wish to append to existing information.

=default charset LOCALE
Use the LOCALE setting by default, which is LC_CTYPE or LC_ALL or LANG
(in that order).  If these contain a character-set which Perl understands,
then that is used, otherwise silently ignored.

=option  format CODE|'LONG'
=default format <adds timestamp>
[1.00] process each printed line.  By default, this adds a timestamp,
but you may want to add hostname, process number, or more.

   format => sub { '['.localtime().'] '.$_[0] }
   format => sub { shift }   # no timestamp
   format => 'LONG'

The first parameter to format is the string to print; it is already
translated and trailed by a newline.  The second parameter is the
text-domain (if known).  The "LONG" format is equivalent to:

  my $t = strftime "%FT%T", gmtime;
  "[$t $$] $_[1] $_[0]"

=cut

sub init($)
{   my ($self, $args) = @_;

    if(!$args->{charset})
    {   my $lc = $ENV{LC_CTYPE} || $ENV{LC_ALL} || $ENV{LANG} || '';
        my $cs = $lc =~ m/\.([\w-]+)/ ? $1 : '';
        $args->{charset} = length $cs && find_encoding $cs ? $cs : undef;
    }

    $self->SUPER::init($args);

    my $name = $self->name;
    my $to   = delete $args->{to}
        or error __x"dispatcher {name} needs parameter 'to'", name => $name;

    if(ref $to)
    {   $self->{output} = $to;
        trace "opened dispatcher $name to a ".ref($to);
    }
    else
    {   $self->{filename} = $to;
        my $binmode = $args->{replace} ? '>' : '>>';

        my $f = $self->{output} = IO::File->new($to, $binmode)
            or fault __x"cannot write log into {file} with mode {binmode}"
                 , binmode => $binmode, file => $to;
        $f->autoflush;

        trace "opened dispatcher $name to $to with $binmode";
    }

    my $format = $args->{format} || sub { '['.localtime()."] $_[0]" };
    $self->{format}
      = ref $format eq 'CODE' ? $format
      : $format eq 'LONG'
      ? sub { my $msg    = shift;
              my $domain = shift || '-';
              my $stamp  = strftime "%FT%T", gmtime;
              "[$stamp $$] $domain $msg"
            }
      : error __x"unknown format parameter `{what}'"
          , what => ref $format || $format;

    $self;
}

=section Accessors

=method filename
Returns the name of the opened file, or C<undef> in case this dispatcher
was started from a file-handle or file-object.

=method format
=method output
=cut

sub filename() {shift->{filename}}
sub format()   {shift->{format}}
sub output()   {shift->{output}}

=section File maintenance

=method close
Only when initiated with a FILENAME, the file will be closed.  In any
other case, nothing will be done.
=cut

sub close()
{   my $self = shift;
    $self->SUPER::close or return;
    $self->output->close if $self->filename;
    $self;
}

=method rotate $filename
[1.00] Move the current file to $filename, and start a new file.
=cut

sub rotate($)
{   my ($self, $new) = @_;

    my $log = $self->filename
        or error __x"cannot rotate log file which was opened as file-handle";

    trace "rotating $log to $new";

    rename $log, $new
        or fault __x"unable to rotate logfile {oldfn} to {newfn}"
              , oldfn => $log, newfn => $new;

    $self->output->close;   # close after move not possible on Windows?
    my $f = $self->{output} = IO::File->new($log, '>>')
        or fault __x"cannot write log into {file}", file => $log;
    $f->autoflush;
    $self;
}

=section Logging
=cut

sub log($$$$)
{   my ($self, $opts, $reason, $msg, $domain) = @_;
    my $text = $self->format->($self->translate($opts, $reason, $msg), $domain);
    my $out  = $self->output;
    flock $out, LOCK_EX;
    $out->print($text);
    flock $out, LOCK_UN;
}

1;
