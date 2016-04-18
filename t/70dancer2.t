#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

BEGIN {
    eval "require Dancer2";
    plan skip_all => 'Dancer2 is not installed'
        if $@;

    plan skip_all => "Dancer2 is too old: $Dancer2::VERSION"
        if $Dancer2::VERSION < 0.151000;   # for to_app()

    warn "Dancer2 version $Dancer2::VERSION\n";

    plan tests => 5;

    eval "require Plack::Test";
    ok !$@, 'Unable to load Plack::Test for Dancer2 tests';

    eval "require HTTP::Cookies";
    ok !$@, 'Unable to load HTTP::Cookies for Dancer2 tests';

    eval "require HTTP::Request::Common";
    ok !$@, 'Unable to load HTTP::Request::Common for Dancer2 tests';
    HTTP::Request::Common->import;
}

{
    package TestApp;
    use Dancer2;
    use Log::Report ();
    use Dancer2::Plugin::LogReport mode => 'NORMAL';  # 'mode' to test import

    set session => 'Simple';
    set logger  => 'LogReport';

    dispatcher close => 'default';

    get '/write_message/:level/:text' => sub {
        my $level = param('level');
        my $text  = param('text');
        eval qq($level "$text");
    };

    get '/read_message' => sub {
        my $all = session 'messages';
        my $message = pop @$all
            or return '';
        "$message";
    };

    get '/process' => sub {
        process(sub { error "Fatal error text" });
    };

}

my $url = 'http://localhost';
my $jar  = HTTP::Cookies->new();
my $test = Plack::Test->create( TestApp->to_app );

# Basic tests to log messages and read from session
subtest 'Basic messages' => sub {

    # Log a notice message
    {
        my $req = GET "$url/write_message/notice/notice_text";
        $jar->add_cookie_header($req);
        my $res = $test->request( $req );
        ok $res->is_success, "get /write_message";
        $jar->extract_cookies($res);

        # Get the message
        $req = GET "$url/read_message";
        $jar->add_cookie_header($req);
        $res = $test->request( $req );
        is ($res->content, 'notice_text');
    }

    # Log a trace message
    {
        my $req = GET "$url/write_message/trace/trace_text";
        $jar->add_cookie_header($req);
        my $res = $test->request( $req );
        ok $res->is_success, "get /write_message";
        $jar->extract_cookies($res);

        # This time it shouldn't make it to the messages session
        $req = GET "$url/read_message";
        $jar->add_cookie_header($req);
        $res = $test->request( $req );
        is ($res->content, '');
    }
};

# Tests to check fatal errors, and catching with process()
subtest 'Throw error' => sub {

    # Throw an uncaught error. Should redirect.
    {
        my $req = GET "$url/write_message/error/error_text";
        my $res = $test->request( $req );
        ok $res->is_redirect, "get /write_message";
    }

    # The same, this time caught and displayed
    {
        my $req = GET "$url/process";
        $jar->add_cookie_header($req);
        my $res = $test->request( $req );
        ok $res->is_success, "get /write_message";
        is ($res->content, '0');

        # Check caught message is in session
        $jar->extract_cookies($res);
        $req = GET "$url/read_message";
        $jar->add_cookie_header($req);
        $res = $test->request( $req );
        is ($res->content, 'Fatal error text');
    }
};

done_testing;

