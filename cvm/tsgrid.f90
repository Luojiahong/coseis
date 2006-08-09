! Generate TeraShake mesh for input to the SCEC VM
! Geoffrey Ely, gely@ucsd.edu, 6/8/2006
program grid
use tscoords_m
implicit none
real :: ell(3), dx
real, allocatable :: x(:,:,:,:)
integer :: n(3), i, reclen
character :: endian

! Dimentions
open( 1, file='dx', status='old' )
read( 1, * ) dx
close( 1 )
ell = (/ 600, 300, 80 /) * 1000
n = nint( ell / dx ) + 1

! 2D mesh
allocate( x(n(1),n(2),1,3) )
forall( i=1:n(1) ) x(i,:,:,1) = dx*(i-1)
forall( i=1:n(2) ) x(:,i,:,2) = dx*(i-1)

! Project TeraShake coordinates to lon/lat
call ts2ll( x, 1, 2 )

! Output
open( 1, file='nn' )
write( 1, * ) product( n )
close( 1 )
inquire( iolength=reclen ) x
open( 1, file='rlon', recl=reclen, form='unformatted', access='direct' )
open( 2, file='rlat', recl=reclen, form='unformatted', access='direct' )
open( 3, file='rdep', recl=reclen, form='unformatted', access='direct' )
do i = 1, n(3)
  x(:,:,:,3) = dx*(i-1)
  write( 1, rec=i ) x(:,:,:,1)
  write( 2, rec=i ) x(:,:,:,2)
  write( 3, rec=i ) x(:,:,:,3)
end do
close( 1 )
close( 2 )
close( 3 )

end program

