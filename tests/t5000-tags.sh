#!/bin/sh

# Copyright (C) 2007-2009 Free Software Foundation, Inc.

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

test_description="test bios_grub flag in gpt labels"

: ${srcdir=.}
. $srcdir/test-lib.sh

dev=loop-file

nb=1024
n_sectors=$(expr $nb '*' 512 / $sector_size_)

test_expect_success \
    "setup: create zeroed device" \
    'dd if=/dev/zero bs=512 count=$nb of=$dev'

test_expect_success \
    'create gpt label' \
    'parted -s $dev mklabel gpt > empty 2>&1'

test_expect_success 'ensure there was no output' \
    'compare /dev/null empty'

test_expect_success \
    'print the table (before adding a partition)' \
    'parted -m -s $dev unit s print > t 2>&1 &&
     sed 's,.*/$dev:,$dev:,' t > out'

test_expect_success \
    'check for expected output' \
    'printf "BYT;\n$dev:${n_sectors}s:file:$sector_size_:$sector_size_:gpt:;\n" > exp &&
     compare exp out'

part_sectors=128
start_sector=60
end_sector=$(expr $start_sector + $part_sectors - 1)
test_expect_success \
    'add a partition' \
    'parted -s $dev mkpart primary ${start_sector}s ${end_sector}s >out 2>&1'

test_expect_success \
    'print the table (before manual modification)' \
    '
     parted -m -s $dev unit s print > t 2>&1 &&
     sed 's,.*/$dev:,$dev:,' t >> out
    '

# Using bios_boot_magic='\x48\x61' looks nicer, but isn't portable.
# dash's builtin printf doesn't recognize such \xHH hexadecimal escapes.
bios_boot_magic='\110\141\150\41\111\144\157\156\164\116\145\145\144\105\106\111'

printf "$bios_boot_magic" | dd of=$dev bs=$sector_size_ seek=2 conv=notrunc

test_expect_success \
    'print the table (after manual modification)' \
    '
     parted -m -s $dev unit s print > t 2>&1
     sed 's,.*/$dev:,$dev:,' t >> out
    '

gen_exp()
{
  cat <<EOF
BYT;
$dev:${n_sectors}s:file:$sector_size_:$sector_size_:gpt:;
1:${start_sector}s:${end_sector}s:${part_sectors}s::primary:;
BYT;
$dev:${n_sectors}s:file:$sector_size_:$sector_size_:gpt:;
1:${start_sector}s:${end_sector}s:${part_sectors}s::primary:bios_grub;
EOF
}

test_expect_success 'check for expected output' \
    '
     gen_exp > exp &&
     compare exp out
    '

test_done
