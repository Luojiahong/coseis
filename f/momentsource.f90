! Moment source added to stress
module m_momentsource
implicit none
real, private, allocatable :: srcfr(:)
integer, private, allocatable :: jj(:), kk(:), ll(:)
contains

! Moment source init
subroutine momentsource_init
use m_globals
use m_diffnc
use m_collective
use m_util
real, allocatable :: cellvol(:)
integer :: i1(3), i2(3), i, j, k, l, j1, k1, l1, j2, k2, l2, nsrc
real :: sumsrcfr

if ( rsource <= 0. ) return
if ( master ) write( 0, * ) 'Moment source initialize'

! Cell volumes
call diffnc( s1, maxval( oper ), x, x, dx, 1, 1, i1cell, i2cell )

! Cell center distance
call vectoraverage( w2, x, i1cell, i2cell, 1 )
do i = 1, 3
  w2(:,:,:,i) = w2(:,:,:,i) - xhypo(i)
end do
s2 = sqrt( sum( w2 * w2, 4 ) )
call sethalo( s2, 2.*rsource, i1cell, i2cell )
nsrc = count( s2 <= rsource )
allocate( jj(nsrc), kk(nsrc), ll(nsrc), cellvol(nsrc), srcfr(nsrc) )

! Use points inside radius
i = 0
i1 = i1cell
i2 = i2cell
j1 = i1(1); j2 = i2(1)
k1 = i1(2); k2 = i2(2)
l1 = i1(3); l2 = i2(3)
do l = l1, l2
do k = k1, k2
do j = j1, j2
if ( s2(j,k,l) <= rsource ) then
  i = i + 1
  jj(i) = j
  kk(i) = k
  ll(i) = l
  cellvol(i) = s1(j,k,l)
  select case( rfunc )
  case( 'box'  ); srcfr(i) = 1.
  case( 'tent' ); srcfr(i) = rsource - s2(j,k,l)
  case default
    write( 0, * ) 'invalid rfunc: ', trim( rfunc )
    stop
  end select
end if
end do
end do
end do

! Normalize and divide by cell volume
call rreduce( sumsrcfr, sum( srcfr ), 'allsum', 0 )
if ( sumsrcfr <= 0. ) stop 'bad source space function'
srcfr = srcfr / sumsrcfr / cellvol

end subroutine

!------------------------------------------------------------------------------!

! Add moment source
subroutine momentsource
use m_globals
integer :: i, j, k, l, ic, nsrc
real :: srcft

if ( rsource <= 0. ) return

! Source time function
select case( tfunc )
case( 'delta'  ); srcft = 1.
case( 'brune'  ); srcft = 1. - exp( -t / tsource ) / tsource * ( t + tsource )
case( 'sbrune' ); srcft = 1. - exp( -t / tsource ) / tsource * &
  ( t + tsource + t * t / tsource / 2. )
case default
  write( 0, * ) 'invalid tfunc: ', trim( tfunc )
  stop
end select

! Add to stress variables
nsrc = size( srcfr )
do ic = 1, 3
do i = 1, nsrc
  j = jj(i)
  k = kk(i)
  l = ll(i)
  w1(j,k,l,ic) = w1(j,k,l,ic) - srcft * srcfr(i) * moment1(ic)
  w2(j,k,l,ic) = w2(j,k,l,ic) - srcft * srcfr(i) * moment2(ic)
end do
end do

end subroutine

end module

