#!/usr/bin/pugs

use v6;
require Test;

plan 29;

=pod

This is a test of the FileSpecWin32 module.

=cut

require File::Spec::Win32;

is(curdir(),  '.',         '... got the right curdir');
is(updir(),   '..',        '... got the right updir');
is(rootdir(), '/',         '... got the right rootdir');
is(devnull(), 'nul', '... got the right devnull');

ok(case_tolerant(), '... Win32 is case tolerant');

{
    my $path = "\\path\\to\\a\\dir";

    my @path = splitdir($path);
    is(+@path, 5, '... we have 5 elements in the path');
    is(@path[0], '', '... our first element is ""');    
    is(@path[1], 'path', '... our second element is "path"');    
    is(@path[2], 'to', '... our third element is "to"');    
    is(@path[3], 'a', '... our fourth element is "a"');    
    is(@path[4], 'dir', '... our fifth element is "dir"');      
    
    is(catdir(@path), $path, '... got the right catdir string');                 
}

{
    my $path = "path\\to\\a\\dir";

    my @path = splitdir($path);
    is(+@path, 4, '... we have 4 elements in the path');
    is(@path[0], 'path', '... our third element is "path"');    
    is(@path[1], 'to', '... our fourth element is "to"');    
    is(@path[2], 'a', '... our fifth element is "a"');      
    is(@path[3], 'dir', '... our second element is "dir"');    
    
    is(catdir(@path), $path, '... got the right catdir string');                 
}

{
    my $path = "\\path\\to\\a\\file.txt";

    my @path = splitdir($path);
    is(+@path, 5, '... we have 5 elements in the path');
    is(@path[0], '', '... our first element is ""');    
    is(@path[1], 'path', '... our second element is "path"');    
    is(@path[2], 'to', '... our third element is "to"');    
    is(@path[3], 'a', '... our fourth element is "a"');    
    is(@path[4], 'file.txt', '... our fifth element is "file.txt"');      
    
    is(catfile(@path), $path, '... got the right catfile string');                 
}

ok(file_name_is_absolute("C:\\\\path\\from\\root"), '... checking if path is absolute (yes)');
ok(!file_name_is_absolute("path\\from\\root"), '... checking if path is absolute (no)');
ok(!file_name_is_absolute("\nC:\\\\path\\from\\root"), '... checking if path is absolute (no)');

is(catpath("C:\\\\", 'dir', 'file'), "C:\\\\dir\\file", 
   '... got the right catpath string (volume is ignored)'); 
   
# {
#     my @upwards = ('path/to/file', '..', '.', ".\n/path");
#     my @no_upwards = no_upwards(@upwards);
#     is(+@no_upwards, 2, '... got one element');
#     is(@no_upwards[0], 'path/to/file', '... got the right element');  
#     is(@no_upwards[1], ".\n/path", '... got the right element');        
# }   
# 
# 
# {
#     my @path = path();
#     ok(+@path, '... we have elements in the path'); 
# 
# #     my $orig_path = %*ENV{'PATH'};
# #     
# #     %*ENV{'PATH'} = 'path/to/bin:path/to/some/other/bin:other/path:';
# #     
# #     my @path = path();
# #     is(+@path, 4, '... we have 4 elements in the path'); 
# #     is(@path[0], 'path/to/bin', '... correct first element in the path'); 
# #     is(@path[1], 'path/to/some/other/bin', '... correct second element in the path'); 
# #     is(@path[2], 'other/path', '... correct third element in the path'); 
# #     is(@path[3], '.', '... correct fourth element in the path');             
# #     
# #     %*ENV{'PATH'} = $orig_path;
# }
# 
# {
#     my @path = splitpath('/path/to/file');
#     is(+@path, 3, '... got back the expected elements');
#     is(@path[0], '', '... got the right first element');    
#     todo_is(@path[1], '/path/to/', '... got the right second element');
#     todo_is(@path[2], 'file', '... got the right third element');    
# }
# 
# {
#     my @path = splitpath('/path/to/file', 1);
#     is(+@path, 3, '... got back the expected elements');
#     is(@path[0], '', '... got the right first element');    
#     is(@path[1], '/path/to/file', '... got the right second element');
#     is(@path[2], '', '... got the right third element');    
# }

# these are tests from the t/Spec.t file from the perl5 File::Spec

# [ "Win32->splitpath('file')",                            ',,file'                            ],
# [ "Win32->splitpath('\\d1/d2\\d3/')",                    ',\\d1/d2\\d3/,'                    ],
# [ "Win32->splitpath('d1/d2\\d3/')",                      ',d1/d2\\d3/,'                      ],
# [ "Win32->splitpath('\\d1/d2\\d3/.')",                   ',\\d1/d2\\d3/.,'                   ],
# [ "Win32->splitpath('\\d1/d2\\d3/..')",                  ',\\d1/d2\\d3/..,'                  ],
# [ "Win32->splitpath('\\d1/d2\\d3/.file')",               ',\\d1/d2\\d3/,.file'               ],
# [ "Win32->splitpath('\\d1/d2\\d3/file')",                ',\\d1/d2\\d3/,file'                ],
# [ "Win32->splitpath('d1/d2\\d3/file')",                  ',d1/d2\\d3/,file'                  ],
# [ "Win32->splitpath('C:\\d1/d2\\d3/')",                  'C:,\\d1/d2\\d3/,'                  ],
# [ "Win32->splitpath('C:d1/d2\\d3/')",                    'C:,d1/d2\\d3/,'                    ],
# [ "Win32->splitpath('C:\\d1/d2\\d3/file')",              'C:,\\d1/d2\\d3/,file'              ],
# [ "Win32->splitpath('C:d1/d2\\d3/file')",                'C:,d1/d2\\d3/,file'                ],
# [ "Win32->splitpath('C:\\../d2\\d3/file')",              'C:,\\../d2\\d3/,file'              ],
# [ "Win32->splitpath('C:../d2\\d3/file')",                'C:,../d2\\d3/,file'                ],
# [ "Win32->splitpath('\\../..\\d1/')",                    ',\\../..\\d1/,'                    ],
# [ "Win32->splitpath('\\./.\\d1/')",                      ',\\./.\\d1/,'                      ],
# [ "Win32->splitpath('\\\\node\\share\\d1/d2\\d3/')",     '\\\\node\\share,\\d1/d2\\d3/,'     ],
# [ "Win32->splitpath('\\\\node\\share\\d1/d2\\d3/file')", '\\\\node\\share,\\d1/d2\\d3/,file' ],
# [ "Win32->splitpath('\\\\node\\share\\d1/d2\\file')",    '\\\\node\\share,\\d1/d2\\,file'    ],
# [ "Win32->splitpath('file',1)",                          ',file,'                            ],
# [ "Win32->splitpath('\\d1/d2\\d3/',1)",                  ',\\d1/d2\\d3/,'                    ],
# [ "Win32->splitpath('d1/d2\\d3/',1)",                    ',d1/d2\\d3/,'                      ],
# [ "Win32->splitpath('\\\\node\\share\\d1/d2\\d3/',1)",   '\\\\node\\share,\\d1/d2\\d3/,'     ],
# 
# [ "Win32->catpath('','','file')",                            'file'                            ],
# [ "Win32->catpath('','\\d1/d2\\d3/','')",                    '\\d1/d2\\d3/'                    ],
# [ "Win32->catpath('','d1/d2\\d3/','')",                      'd1/d2\\d3/'                      ],
# [ "Win32->catpath('','\\d1/d2\\d3/.','')",                   '\\d1/d2\\d3/.'                   ],
# [ "Win32->catpath('','\\d1/d2\\d3/..','')",                  '\\d1/d2\\d3/..'                  ],
# [ "Win32->catpath('','\\d1/d2\\d3/','.file')",               '\\d1/d2\\d3/.file'               ],
# [ "Win32->catpath('','\\d1/d2\\d3/','file')",                '\\d1/d2\\d3/file'                ],
# [ "Win32->catpath('','d1/d2\\d3/','file')",                  'd1/d2\\d3/file'                  ],
# [ "Win32->catpath('C:','\\d1/d2\\d3/','')",                  'C:\\d1/d2\\d3/'                  ],
# [ "Win32->catpath('C:','d1/d2\\d3/','')",                    'C:d1/d2\\d3/'                    ],
# [ "Win32->catpath('C:','\\d1/d2\\d3/','file')",              'C:\\d1/d2\\d3/file'              ],
# [ "Win32->catpath('C:','d1/d2\\d3/','file')",                'C:d1/d2\\d3/file'                ],
# [ "Win32->catpath('C:','\\../d2\\d3/','file')",              'C:\\../d2\\d3/file'              ],
# [ "Win32->catpath('C:','../d2\\d3/','file')",                'C:../d2\\d3/file'                ],
# [ "Win32->catpath('','\\../..\\d1/','')",                    '\\../..\\d1/'                    ],
# [ "Win32->catpath('','\\./.\\d1/','')",                      '\\./.\\d1/'                      ],
# [ "Win32->catpath('\\\\node\\share','\\d1/d2\\d3/','')",     '\\\\node\\share\\d1/d2\\d3/'     ],
# [ "Win32->catpath('\\\\node\\share','\\d1/d2\\d3/','file')", '\\\\node\\share\\d1/d2\\d3/file' ],
# [ "Win32->catpath('\\\\node\\share','\\d1/d2\\','file')",    '\\\\node\\share\\d1/d2\\file'    ],
# 
# [ "Win32->splitdir('')",             ''           ],
# [ "Win32->splitdir('\\d1/d2\\d3/')", ',d1,d2,d3,' ],
# [ "Win32->splitdir('d1/d2\\d3/')",   'd1,d2,d3,'  ],
# [ "Win32->splitdir('\\d1/d2\\d3')",  ',d1,d2,d3'  ],
# [ "Win32->splitdir('d1/d2\\d3')",    'd1,d2,d3'   ],
# 
# [ "Win32->catdir()",                        ''                   ],
# [ "Win32->catdir('')",                      '\\'                 ],
# [ "Win32->catdir('/')",                     '\\'                 ],
# [ "Win32->catdir('/', '../')",              '\\'                 ],
# [ "Win32->catdir('/', '..\\')",             '\\'                 ],
# [ "Win32->catdir('\\', '../')",             '\\'                 ],
# [ "Win32->catdir('\\', '..\\')",            '\\'                 ],
# [ "Win32->catdir('//d1','d2')",             '\\\\d1\\d2'         ],
# [ "Win32->catdir('\\d1\\','d2')",           '\\d1\\d2'         ],
# [ "Win32->catdir('\\d1','d2')",             '\\d1\\d2'         ],
# [ "Win32->catdir('\\d1','\\d2')",           '\\d1\\d2'         ],
# [ "Win32->catdir('\\d1','\\d2\\')",         '\\d1\\d2'         ],
# [ "Win32->catdir('','/d1','d2')",           '\\\\d1\\d2'         ],
# [ "Win32->catdir('','','/d1','d2')",        '\\\\\\d1\\d2'       ],
# [ "Win32->catdir('','//d1','d2')",          '\\\\\\d1\\d2'       ],
# [ "Win32->catdir('','','//d1','d2')",       '\\\\\\\\d1\\d2'     ],
# [ "Win32->catdir('','d1','','d2','')",      '\\d1\\d2'           ],
# [ "Win32->catdir('','d1','d2','d3','')",    '\\d1\\d2\\d3'       ],
# [ "Win32->catdir('d1','d2','d3','')",       'd1\\d2\\d3'         ],
# [ "Win32->catdir('','d1','d2','d3')",       '\\d1\\d2\\d3'       ],
# [ "Win32->catdir('d1','d2','d3')",          'd1\\d2\\d3'         ],
# [ "Win32->catdir('A:/d1','d2','d3')",       'A:\\d1\\d2\\d3'     ],
# [ "Win32->catdir('A:/d1','d2','d3','')",    'A:\\d1\\d2\\d3'     ],
# #[ "Win32->catdir('A:/d1','B:/d2','d3','')", 'A:\\d1\\d2\\d3'     ],
# [ "Win32->catdir('A:/d1','B:/d2','d3','')", 'A:\\d1\\B:\\d2\\d3' ],
# [ "Win32->catdir('A:/')",                   'A:\\'               ],
# [ "Win32->catdir('\\', 'foo')",             '\\foo'              ],
# 
# [ "Win32->catfile('a','b','c')",        'a\\b\\c' ],
# [ "Win32->catfile('a','b','.\\c')",      'a\\b\\c'  ],
# [ "Win32->catfile('.\\a','b','c')",      'a\\b\\c'  ],
# [ "Win32->catfile('c')",                'c' ],
# [ "Win32->catfile('.\\c')",              'c' ],
# 
# 
# [ "Win32->canonpath('')",               ''                    ],
# [ "Win32->canonpath('a:')",             'A:'                  ],
# [ "Win32->canonpath('A:f')",            'A:f'                 ],
# [ "Win32->canonpath('A:/')",            'A:\\'                ],
# [ "Win32->canonpath('//a\\b//c')",      '\\\\a\\b\\c'         ],
# [ "Win32->canonpath('/a/..../c')",      '\\a\\....\\c'        ],
# [ "Win32->canonpath('//a/b\\c')",       '\\\\a\\b\\c'         ],
# [ "Win32->canonpath('////')",           '\\\\\\'              ],
# [ "Win32->canonpath('//')",             '\\'                  ],
# [ "Win32->canonpath('/.')",             '\\.'                 ],
# [ "Win32->canonpath('//a/b/../../c')",  '\\\\a\\b\\c'         ],
# [ "Win32->canonpath('//a/b/c/../d')",   '\\\\a\\b\\d'         ],
# [ "Win32->canonpath('//a/b/c/../../d')",'\\\\a\\b\\d'         ],
# [ "Win32->canonpath('//a/b/c/.../d')",  '\\\\a\\b\\d'         ],
# [ "Win32->canonpath('/a/b/c/../../d')", '\\a\\d'              ],
# [ "Win32->canonpath('/a/b/c/.../d')",   '\\a\\d'              ],
# [ "Win32->canonpath('\\../temp\\')",    '\\temp'              ],
# [ "Win32->canonpath('\\../')",          '\\'                  ],
# [ "Win32->canonpath('\\..\\')",         '\\'                  ],
# [ "Win32->canonpath('/../')",           '\\'                  ],
# [ "Win32->canonpath('/..\\')",          '\\'                  ],
# [ "Win32->can('_cwd')",                 '/CODE/'              ],


