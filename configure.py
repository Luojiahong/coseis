#!/usr/bin/env python
"""
Read configuration files
"""

def configure( machine=None, save=False ):
    """Read configuration files"""
    import os
    import util
    cwd = os.getcwd()
    os.chdir( os.path.realpath( os.path.dirname( __file__ ) ) )
    conf = { 'machine': 'default' }
    util.load( 'default-cfg.py', conf )
    if not machine and os.path.isfile( 'machine' ):
        machine = file( 'machine', 'r' ).read().strip()
    if machine:
        util.load( 'conf/' + machine + '/conf.py', conf )
        conf['machine'] = machine
    if save:
        file( 'machine', 'w' ).write( conf['machine'] )
    os.chdir( cwd )
    return conf

if __name__ == '__main__':
    """Test configuration"""
    import os, sys
    c = configure( *sys.argv[1:2], True )
    print c['notes']
    for k, v in c.iteritems():
        if k != 'notes':
            print '%s = %r' % ( k, v )

