!------------------------------------------------------------------------------!
! SORD

program sord

use globals_m
use input_m
use setup_m
use gridgen_m
use matmodel_m
use pml_m
use fault_m
use momentsrc_m
use vstep_m
use wstep_m
use output_m

print '(a)', ''
print '(a)', 'SORD - Support Operator Rupture Dynamics'

call input
call setup
call gridgen
call matmodel
call pml
call fault
call momentsrc
call output( 'v' )

do while ( it < nt )
  it = it + 1;
  call system_clock( wt(1) ); call wstep
  call system_clock( wt(2) ); call output( 'w' )
  call system_clock( wt(3) ); call vstep
  call system_clock( wt(4) ); call output( 'v' )
end do

end program

