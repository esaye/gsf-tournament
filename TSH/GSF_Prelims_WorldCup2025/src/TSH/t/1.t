# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More;
BEGIN { plan tests => 4 };
use TSH::Pair;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

ok(TSH::Pair::square(4) == 16, '4 squared');
ok(TSH::Pair::square(-1) == 1, '-1 squared');
ok(TSH::Pair::square(65535) == 4294836225, '65535 squared');
