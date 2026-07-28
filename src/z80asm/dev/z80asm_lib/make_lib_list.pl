#------------------------------------------------------------------------------
# Z80 assembler
# Copyright (C) Paulo Custodio, 2011-2026
# License: The Artistic License 2.0, http://www.perlfoundation.org/artistic_license_2_0
#------------------------------------------------------------------------------

use feature 'say';	# local macOS build patch: was `use Modern::Perl` (only used for say)

for (sort @ARGV) {
	next if /^test/;
	say;
}
