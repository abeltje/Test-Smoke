/* ********************************************************************** *
 *                                                                        *
 * $Id$                                                                   *
 *                                                                        *
 * 01test.c is a stupid program that can be compiled in three ways:       *
 *                                                                        *
 *   1) no defines (perl)                                                 *
 *   2) -DMINI (miniperl)                                                 *
 *   3) -DDO_ERROR generates a syntaxerror                                *
 *                                                                        *
 * ********************************************************************** */
#include <stdio.h>
#include "patchlevel.h"

int
main ()
{
    float ver = 0.002;
#ifdef MINI
    printf( "This is fake miniperl, %.3f with %s\n", ver, local_patches[1] );
#else
    printf( "This is fake perl, %.3f with %s\n", ver, local_patches[1] );
#endif

#ifdef DO_ERROR
#    ifndef MINI
        printf( 'Syntax error' );
#    endif
#endif
}

/* **********************************************************************
 *
 * (c) 2002-2003, All rights reserved.
 * 
 *   * Abe Timmerman <abeltje@cpan.org>
 * 
 * This library is free software; you can redistribute it and/or modify
 * it under the same terms as Perl itself.
 * 
 * See:
 * 
 *   * http://www.perl.com/perl/misc/Artistic.html
 *   * http://www.gnu.org/copyleft/gpl.html
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * 
 *
 * ***********************************************************************/
