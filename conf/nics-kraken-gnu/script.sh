#!/bin/bash -e

##PBS -A TG-MCA03S012
#PBS -N %(name)s
#PBS -M %(email)s
#PBS -l size=%(totalcores)s
#PBS -l walltime=%(walltime)s
#PBS -o %(rundir)s/stdout
#PBS -e %(rundir)s/stderr
#PBS -m abe
#PBS -V

cd "%(rundir)s"
set > env

echo "$( date ): %(name)s started" >> log
%(pre)s
aprun -n %(nproc)s %(command)s
%(post)s
echo "$( date ): %(name)s finished" >> log

