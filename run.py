#!/usr/bin/env python
"""
SORD main module
"""

import os, sys, pwd, glob, time, getopt, shutil
import util, configure, setup, fieldnames

def run( inputs ):
    """Setup, and optionally launch, a SORD job."""

    # Save start time
    starttime = time.asctime()
    print "SORD setup"

    # Read defaults
    prm = util.load( os.path.dirname( __file__ ) + os.sep + 'default-prm.py' )
    if 'machine' in inputs:
        cfg = configure.configure( machine=inputs['machine'] )
    else:
        cfg = configure.configure()
    if '__file__' in inputs:
        cfg['name'] = os.path.splitext( os.path.basename( inputs['__file__'] ) )[0]
        cfg['rundir'] += os.sep + cfg['name'] 

    # Merge inputs
    for k, v in inputs.iteritems():
        if k[0] is not '_' and type(v) is not type(sys):
            if k in cfg:
                cfg[k] = v
            elif k in prm:
                prm[k] = v
            else:
                sys.exit( 'Unknown parameter: %s = %r' % ( k, v ) )
    cfg = util.objectify( cfg )
    prm = prepare_prm( util.objectify( prm ), cfg.itbuff )

    # Command line options
    opts = [
        'n', 'dryrun',
        's', 'serial',
        'm', 'mpi',
        'i', 'interactive',
        'q', 'queue',
        '',  'debug',
        'g', 'debugging',
        't', 'testing',
        'p', 'profiling',
        'O', 'optimized',
        'f', 'force',
    ]
    options = ''.join( opts[::2] )
    long_options = opts[1::2]
    opts, args = getopt.getopt( sys.argv[1:], options, long_options )
    for o, v in opts:
        if   o in ('-n', '--dry-run'):     cfg.prepare = False
        elif o in ('-s', '--serial'):      cfg.mode = 's'
        elif o in ('-m', '--mpi'):         cfg.mode = 'm'
        elif o in ('-i', '--interactive'): cfg.run = 'i'
        elif o in ('-q', '--queue'):       cfg.run = 'q'
        elif o in ('-d', '--debug'):       cfg.optimize = 'g'; cfg.run = 'g'
        elif o in ('-g', '--debugging'):   cfg.optimize = 'g'
        elif o in ('-t', '--testing'):     cfg.optimize = 't'
        elif o in ('-p', '--profiling'):   cfg.optimize = 'p'
        elif o in ('-O', '--optimized'):   cfg.optimize = 'O'
        elif o in ('-f', '--force'):
            if os.path.isdir( cfg.rundir ): shutil.rmtree( cfg.rundir )
        else: sys.exit( 'Error: unknown option: ' + o )
    if not cfg.prepare: cfg.run = False

    # Partition for parallelization
    prm.nn = tuple( prm.nn )
    maxtotalcores = cfg.maxnodes * cfg.maxcores
    if not cfg.mode and maxtotalcores == 1:
        cfg.mode = 's'
    np3 = prm.np3[:]
    if cfg.mode == 's':
        np3 = [ 1, 1, 1 ]
    nl = [ ( prm.nn[i] - 1 ) / np3[i] + 1 for i in range(3) ]
    i  = abs( prm.faultnormal ) - 1
    if i >= 0:
        nl[i] = max( nl[i], 2 )
    np3 = [ ( prm.nn[i] - 1 ) / nl[i] + 1 for i in range(3) ]
    prm.np3 = tuple( np3 )
    cfg.np = np3[0] * np3[1] * np3[2]
    if not cfg.mode:
        cfg.mode = 's'
        if cfg.np > 1:
            cfg.mode = 'm'

    # Resources
    if cfg.maxcores:
        cfg.nodes = min( cfg.maxnodes, ( cfg.np - 1 ) / cfg.maxcores + 1 )
        cfg.ppn = ( cfg.np - 1 ) / cfg.nodes + 1
        cfg.cores = min( cfg.maxcores, cfg.ppn )
        cfg.totalcores = cfg.nodes * cfg.maxcores
    else:
        cfg.nodes = 1
        cfg.ppn = cfg.np
        cfg.cores = cfg.np
        cfg.totalcores = cfg.np

    # RAM and Wall time usage
    if prm.oplevel in (1,2):
         nvars = 20
    elif prm.oplevel in (3,4,5):
         nvars = 23
    else:
         nvars = 44
    nm = ( nl[0] + 2 ) * ( nl[1] + 2 ) * ( nl[2] + 2 )
    cfg.ram = ( nm * nvars * cfg.floatsize / 1024 / 1024 + 10 ) * cfg.ppn
    sus = int( ( prm.nt + 10 ) * cfg.ppn * nm / cfg.cores / cfg.rate / 3600 * cfg.totalcores + 1 )
    mm  =      ( prm.nt + 10 ) * cfg.ppn * nm / cfg.cores / cfg.rate / 60 * 3.0 + 10
    if cfg.maxtime:
        mm = min( 60*cfg.maxtime[0] + cfg.maxtime[1], mm )
    hh = mm / 60
    mm = mm % 60
    cfg.walltime = '%d:%02d:00' % ( hh, mm )
    print 'Machine: ' + cfg.machine
    print 'Cores: %s of %s' % ( cfg.np, maxtotalcores )
    print 'Nodes: %s of %s' % ( cfg.nodes, cfg.maxnodes )
    print 'RAM: %sMb of %sMb per node' % ( cfg.ram, cfg.maxram )
    print 'Time limit: ' + cfg.walltime
    print 'SUs: %s' % sus
    if cfg.maxcores and cfg.ppn > cfg.maxcores:
        print 'Warning: exceding available cores per node (%s)' % cfg.maxcores
    if cfg.ram and cfg.ram > cfg.maxram:
        print 'Warning: exceding available RAM per node (%sMb)' % cfg.maxram

    # Compile code
    if not cfg.prepare: return
    setup.build( cfg.mode, cfg.optimize )

    # Create run directory
    print 'Run directory: ' + cfg.rundir
    try:
        os.makedirs( cfg.rundir )
    except:
        sys.exit( 'Directory %r already exists or cannot be created. Use --force to overwrite.' % cfg.rundir )
    for f in ( 'in', 'out', 'prof', 'stats', 'debug', 'checkpoint' ):
        os.mkdir( cfg.rundir + os.sep + f )

    # Link input files
    for i, line in enumerate( prm.fieldio ):
        if 'r' in line[0] and os.sep in line[3]:
            filename = line[3]
            f = os.path.basename( filename )
            line = line[:3] + ( f, ) + line[4:]
            prm.fieldio[i] = line
            f = 'in' + os.sep + filename
            try:
                os.link( filename, cfg.rundir + os.sep + f )
            except:
                shutil.copy( filename, cfg.rundir + os.sep + f )

    # Copy files to run directory
    cwd = os.path.realpath( os.getcwd() )
    cfg.rundate = time.asctime()
    cfg.name += '-' + os.path.basename( cfg.rundir )
    cfg.rundir = os.path.realpath( cfg.rundir )
    os.chdir( os.path.realpath( os.path.dirname( __file__ ) ) )
    cfg.bin = '.' + os.sep + 'sord-' + cfg.mode + cfg.optimize
    shutil.copy( 'bin' + os.sep + 'sord-' + cfg.mode + cfg.optimize, cfg.rundir )
    try: shutil.cop( 'sord.tgz', cfg.rundir )
    except: pass
    if cfg.optimize == 'g':
        for f in glob.glob( 'src/*.f90' ):
            shutil.copy( f, cfg.rundir )
    f = 'conf/' + cfg.machine + '/templates'
    if not os.path.isdir( f ):
        f = 'conf/default/templates'
    for d in [ 'conf/common/templates', f ]:
        for f in glob.glob( d + os.sep + '*' ):
            ff = cfg.rundir + os.sep + os.path.basename( f )
            out = file( f, 'r' ).read() % util.dictify( cfg )
            file( ff, 'w' ).write( out )
            shutil.copymode( f, ff )

    # Write files
    os.chdir( cfg.rundir )
    log = file( 'log', 'w' )
    log.write( starttime + ': setup started\n' )
    util.save( 'parameters.py', util.dictify( prm ), [ 'fieldio' ] )
    util.save( 'conf.py', util.dictify( cfg ) )

    # Run or queue job
    if cfg.run == 'q':
        print 'queue.sh'
        if cfg.host not in cfg.hosts:
            sys.exit( 'Error: hostname %r does not match configuration %r' % ( cfg.host, cfg.machine ) )
        if os.system( '.' + os.sep + 'queue.sh' ):
            sys.exit( 'Error queing job' )
    elif cfg.run:
        print 'run.sh -' + cfg.run
        if cfg.host not in cfg.hosts:
            sys.exit( 'Error: hostname %r does not match configuration %r' % ( cfg.host, cfg.machine ) )
        if os.system( '.' + os.sep + 'run.sh -' + cfg.run ):
            sys.exit( 'Error running job' )

    # Return to initial directory
    os.chdir( cwd )

def prepare_prm( prm, itbuff ):
    """Prepare input paramers"""

    # inervals
    prm.itio = max( 1, min( prm.itio, prm.nt ) )
    if prm.itcheck % prm.itio != 0:
        prm.itcheck = ( prm.itcheck / prm.itio + 1 ) * prm.itio

    # hypocenter node
    ii = list( prm.ihypo )
    for i in range( 3 ):
        if ii[i] == 0:
            ii[i] = prm.nn[i] / 2
        elif ii[i] < 0:
            ii[i] = ii[i] + prm.nn[i] + 1
        if ii[i] < 1 or ii[i] > prm.nn[i]:
            sys.exit( 'Error: ihypo %s out of bounds' % ii )
    prm.ihypo = tuple( ii )

    # boundary conditions
    i1 = list( prm.bc1 )
    i2 = list( prm.bc2 )
    i = abs( prm.faultnormal ) - 1
    if i >= 0:
        if prm.ihypo[i] == 1:             i1[i] = -2
        if prm.ihypo[i] == prm.nn[i] - 1: i2[i] = -2
        if prm.ihypo[i] >= prm.nn[i]: sys.exit( 'Error: ihypo %s out of bounds' % ii )
    prm.bc1 = tuple( i1 )
    prm.bc2 = tuple( i2 )

    # PML region
    i1 = [ 0, 0, 0 ]
    i2 = [ n+1 for n in prm.nn ]
    if prm.npml > 0:
        for i in range( 3 ):
            if prm.bc1[i] == 10: i1[i] = prm.npml
            if prm.bc2[i] == 10: i2[i] = prm.nn[i] - prm.npml + 1
            if i1[i] > i2[i]: sys.exit( 'Error: model too small for PML' )
    prm.i1pml = tuple( i1 )
    prm.i2pml = tuple( i2 )

    # I/O sequence
    fieldio = []
    for line in prm.fieldio:
        line = list( line )
        filename = '-'
        tfunc, val, period = 'const', 1.0, 1.0
        x1 = x2 = 0., 0., 0.
        op = line[0][0]
        mode = line[0][1:]
        if op not in '=+': sys.exit( 'Error: unsupported operator: %r' % line )
        try:
            if len(line) is 10:
                tfunc, period, x1, x2, nb, ii, field, filename, val   = line[1:]
            elif mode == '':    field, ii, val                        = line[1:]
            elif mode == 's':   field, ii, val                        = line[1:]
            elif mode == 'x':   field, ii, val, x1                    = line[1:]
            elif mode == 'sx':  field, ii, val, x1                    = line[1:]
            elif mode == 'c':   field, ii, val, x1, x2                = line[1:]
            elif mode == 'f':   field, ii, val, tfunc, period         = line[1:]
            elif mode == 'fs':  field, ii, val, tfunc, period         = line[1:]
            elif mode == 'fx':  field, ii, val, tfunc, period, x1     = line[1:]
            elif mode == 'fsx': field, ii, val, tfunc, period, x1     = line[1:]
            elif mode == 'fc':  field, ii, val, tfunc, period, x1, x2 = line[1:]
            elif mode == 'r':   field, ii, filename                   = line[1:]
            elif mode == 'w':   field, ii, filename                   = line[1:]
            elif mode == 'rx':  field, ii, filename, x1               = line[1:]
            elif mode == 'wx':  field, ii, filename, x1               = line[1:]
            else: sys.exit( 'Error: bad i/o mode: %r' % line )
        except:
            sys.exit( 'Error: bad i/o spec: %r' % line )
        mode = mode.replace( 'f', '' )
        if field not in fieldnames.all:
            sys.exit( 'Error: unknown field: %r' % line )
        if prm.faultnormal == 0 and field in fieldnames.fault:
            sys.exit( 'Error: field only for ruptures: %r' % line )
        if 'w' not in mode and field not in fieldnames.input:
            sys.exit( 'Error: field is ouput only: %r' % line )
        if 'r' in mode:
            fn = os.path.dirname( filename ) + os.sep + 'endian'
            if file( fn, 'r' ).read()[0] != sys.byteorder[0]:
                sys.exit( 'Error: wrong byte order for ' + filename )
        nn = list( prm.nn ) + [ prm.nt ]
        ii = util.indices( ii, nn )
        if field in fieldnames.cell:
            ii = [ (i[0], i[1]-1, i[2]) for i in ii ]
            mode = mode.replace( 'x', 'X' )
            mode = mode.replace( 'c', 'C' )
        if field in fieldnames.initial:
            ii[3] = 0, 0, 1
        if field in fieldnames.fault:
            i = prm.faultnormal - 1
            ii[i] = 2 * ( prm.ihypo[i], ) + ( 1, )
        nn = [ ( ii[i][1] - ii[i][0] + 1 ) / ii[i][2] for i in range(4) ]
        nb = ( min( prm.itio, prm.nt ) - 1 ) / ii[3][2] + 1
        nb = max( 1, min( nb, nn[3] ) )
        if 'x' not in mode and 'X' not in mode:
            n = nn[0] * nn[1] * nn[2]
            if n > ( prm.nn[0] + prm.nn[1] + prm.nn[2] ) ** 2:
                nb = 1
            elif n > 1:
                nb = min( nb, itbuff )
        fieldio += [( op+mode, tfunc, period, x1, x2, nb, ii, field, filename, val )]
    f = [ line[8] for line in fieldio if line[8] != '-' ]
    for i in range( len( f ) ):
        if f[i] in f[:i]:
            sys.exit( 'Error: duplicate filename: %r' % f[i] )
    prm.fieldio = fieldio
    return prm

