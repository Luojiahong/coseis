! Fault boundary condition
module m_fault
implicit none
contains

! Fault initialization
subroutine fault_init
use m_globals
use m_collective
use m_surfnormals
use m_util
real :: rr
integer :: i1(3), i2(3), i3(3), i4(3), ifill(3), i, j, k, l
real, pointer :: f(:,:,:)
type( t_io ), pointer :: p

if ( ifn == 0 ) return
if ( master ) write( 0, * ) 'Fault initialization'

! Input
mus = 0.
mud = 0.
dc = 0.
co = 0.
t1 = 0.
t2 = 0.
t3 = 0.
call input( 'mus', mus         )
call input( 'mud', mud         )
call input( 'dc',  dc          )
call input( 'co',  co          )
call input( 'sxx', t1(:,:,:,1) )
call input( 'syy', t1(:,:,:,2) )
call input( 'szz', t1(:,:,:,3) )
call input( 'syz', t2(:,:,:,1) )
call input( 'szx', t2(:,:,:,2) )
call input( 'sxy', t2(:,:,:,3) )
call input( 'ts1', t3(:,:,:,1) )
call input( 'ts2', t3(:,:,:,2) )
call input( 'tn',  t3(:,:,:,3) )

! Test for endian problems
if ( any( mus /= mus ) .or. maxval( mus ) > huge( rr ) ) stop 'NaN/Inf in mus'
if ( any( mud /= mud ) .or. maxval( mud ) > huge( rr ) ) stop 'NaN/Inf in mud'
if ( any( dc  /= dc  ) .or. maxval( dc  ) > huge( rr ) ) stop 'NaN/Inf in dc'
if ( any( co  /= co  ) .or. maxval( co  ) > huge( rr ) ) stop 'NaN/Inf in co'
if ( any( t1  /= t1  ) .or. maxval( t1  ) > huge( rr ) ) stop 'NaN/Inf in stress model'
if ( any( t2  /= t2  ) .or. maxval( t2  ) > huge( rr ) ) stop 'NaN/Inf in stress model'
if ( any( t3  /= t3  ) .or. maxval( t3  ) > huge( rr ) ) stop 'NaN/Inf in traction model'

! Normal traction check
i1 = maxloc( t3(:,:,:,3) )
rr = t3(i1(1),i1(2),i1(3),3)
i1(ifn) = ihypo(ifn)
i1 = i1 + nnoff
if ( rr > 0. ) write( 0, * ) 'warning: positive normal traction: ', rr, i1

! Lock fault in PML region
i1 = i1pml + 1
i2 = i2pml - 1
call scalar_set_halo( co, 1e20, i1, i2 )

! Normal vectors
i1 = i1core
i2 = i2core
i1(ifn) = ihypo(ifn)
i2(ifn) = ihypo(ifn)
call surfnormals( nhat, w1, i1, i2, ifn )
area = sign( 1, faultnormal ) * sqrt( sum( nhat * nhat, 4 ) )
f1 = area
call invert( f1 )
do i = 1, 3
  nhat(:,:,:,i) = nhat(:,:,:,i) * f1
end do

! Resolve prestress onto fault
do i = 1, 3
  j = modulo( i , 3 ) + 1
  k = modulo( i + 1, 3 ) + 1
  t0(:,:,:,i) = &
  t1(:,:,:,i) * nhat(:,:,:,i) + &
  t2(:,:,:,j) * nhat(:,:,:,k) + &
  t2(:,:,:,k) * nhat(:,:,:,j)
end do

! Ts2 vector
t2(:,:,:,1) = nhat(:,:,:,2) * slipvector(3) - nhat(:,:,:,3) * slipvector(2)
t2(:,:,:,2) = nhat(:,:,:,3) * slipvector(1) - nhat(:,:,:,1) * slipvector(3)
t2(:,:,:,3) = nhat(:,:,:,1) * slipvector(2) - nhat(:,:,:,2) * slipvector(1)
f1 = sqrt( sum( t2 * t2, 4 ) )
call invert( f1 )
do i = 1, 3
  t2(:,:,:,i) = t2(:,:,:,i) * f1
end do

! Ts1 vector
t1(:,:,:,1) = t2(:,:,:,2) * nhat(:,:,:,3) - t2(:,:,:,3) * nhat(:,:,:,2)
t1(:,:,:,2) = t2(:,:,:,3) * nhat(:,:,:,1) - t2(:,:,:,1) * nhat(:,:,:,3)
t1(:,:,:,3) = t2(:,:,:,1) * nhat(:,:,:,2) - t2(:,:,:,2) * nhat(:,:,:,1)
f1 = sqrt( sum( t1 * t1, 4 ) )
call invert( f1 )
do i = 1, 3
  t1(:,:,:,i) = t1(:,:,:,i) * f1
end do

! Total pretraction
do i = 1, 3
  t0(:,:,:,i) = t0(:,:,:,i) + &
  t3(:,:,:,1) * t1(:,:,:,i) + &
  t3(:,:,:,2) * t2(:,:,:,i) + &
  tn * nhat(:,:,:,i)
end do

! Hypocentral radius
do i = 1, 3
  select case( ifn )
  case ( 1 ); t2(1,:,:,i) = w1(ihypo(1),:,:,i) - xhypo(i)
  case ( 2 ); t2(:,1,:,i) = w1(:,ihypo(2),:,i) - xhypo(i)
  case ( 3 ); t2(:,:,1,i) = w1(:,:,ihypo(3),i) - xhypo(i)
  end select
end do
rhypo = sqrt( sum( t2 * t2, 4 ) )

! Resample mu on to fault plane nodes for moment calculatioin
select case( ifn )
case ( 1 ); muf(1,:,:) = mu(ihypo(1),:,:)
case ( 2 ); muf(:,1,:) = mu(:,ihypo(2),:)
case ( 3 ); muf(:,:,1) = mu(:,:,ihypo(3))
end select
call invert( muf )
j = nm(1) - 1
k = nm(2) - 1
l = nm(3) - 1
if ( ifn /= 1 ) muf(2:j,:,:) = .5 * ( muf(2:j,:,:) + muf(1:j-1,:,:) )
if ( ifn /= 2 ) muf(:,2:k,:) = .5 * ( muf(:,2:k,:) + muf(:,1:k-1,:) )
if ( ifn /= 3 ) muf(:,:,2:l) = .5 * ( muf(:,:,2:l) + muf(:,:,1:l-1) )
call invert( muf )

! Save for output
tn = sum( t0 * nhat, 4 )
do i = 1, 3
  t2(:,:,:,i) = tn * nhat(:,:,:,i)
end do
t3 = t0 - t2
ts = sqrt( sum( t3 * t3, 4 ) )
f1 = 0.
f2 = 0.
t1 = 0.
t2 = 0.

! Initial state, can be overwritten by read_checkpoint
psv   =  0.
trup  =  1e9
tarr  =  0.
efric =  0.

! Output
if ( it == 0 ) then
  p => pio0
  do while( associated( p%next ) )
    p => p%next
    call rio4( 'out', 'mus',  mus         )
    call rio4( 'out', 'mud',  mud         )
    call rio4( 'out', 'dc',   dc          )
    call rio4( 'out', 'co',   co          )
    call rio4( 'out', 'ts1',  t3(:,:,:,1) )
    call rio4( 'out', 'ts2',  t3(:,:,:,2) )
    call rio4( 'out', 'ts3',  t3(:,:,:,2) )
    call rio4( 'out', 'sa1',  t2(:,:,:,1) )
    call rio4( 'out', 'sa2',  t2(:,:,:,2) )
    call rio4( 'out', 'sa3',  t2(:,:,:,3) )
    call rio4( 'out', 'sv1',  t1(:,:,:,1) )
    call rio4( 'out', 'sv2',  t1(:,:,:,2) )
    call rio4( 'out', 'sv3',  t1(:,:,:,3) )
    call rio4( 'out', 'su1',  t2(:,:,:,1) )
    call rio4( 'out', 'su2',  t2(:,:,:,2) )
    call rio4( 'out', 'su3',  t2(:,:,:,3) )
    call rio4( 'out', 'svm',  f1          )
    call rio4( 'out', 'sum',  f2          )
    call rio4( 'out', 'psv',  psv         )
    call rio4( 'out', 'tn',   tn          )
    call rio4( 'out', 'tsm',  ts          )
    call rio4( 'out', 'sam',  f2          )
    call rio4( 'out', 'tn',   tn          )
    call rio4( 'out', 'fr',   f1          )
    call rio4( 'out', 'sl',   sl          )
    call rio4( 'out', 'trup', trup        )
    call rio4( 'out', 'tarr', tarr        )
  end do
end if

! Halos
call scalar_swap_halo( mus,   nhalo )
call scalar_swap_halo( mud,   nhalo )
call scalar_swap_halo( dc,    nhalo )
call scalar_swap_halo( co,    nhalo )
call scalar_swap_halo( area,  nhalo )
call scalar_swap_halo( rhypo, nhalo )
call vector_swap_halo( nhat,  nhalo )
call vector_swap_halo( t0,    nhalo )

! Metadata
if ( master ) then
  i1 = ihypo
  i1(ifn) = 1
  j = i1(1)
  k = i1(2)
  l = i1(3)
  mu0 = muf(j,k,l)
  mus0 = mus(j,k,l)
  mud0 = mud(j,k,l)
  dc0 = dc(j,k,l)
  tn0 = sum( t0(j,k,l,:) * nhat(j,k,l,:) )
  ts0 = sqrt( sum( ( t0(j,k,l,:) - tn0 * nhat(j,k,l,:) ) ** 2. ) )
  tn0 = max( -tn0, 0. )
  ess = ( tn0 * mus0 - ts0 ) / ( ts0 - tn0 * mud0 )
  lc =  dc0 * mu0 / tn0 / ( mus0 - mud0 )
  if ( tn0 * ( mus0 - mud0 ) == 0. ) lc = 0.
  rctest = mu0 * tn0 * ( mus0 - mud0 ) * dc0 / ( ts0 - tn0 * mud0 ) ** 2
end if

end subroutine

!------------------------------------------------------------------------------!

! Fault boundary condition
subroutine fault
use m_globals
use m_collective
use m_bc
use m_util
integer :: i1(3), i2(3), i, j1, k1, l1, j2, k2, l2, j3, k3, l3, j4, k4, l4

if ( ifn == 0 ) return
if ( master .and. debug == 2 ) write( 0, * ) 'Fault'

! Indices
i1 = 1
i2 = nm
i1(ifn) = ihypo(ifn)
i2(ifn) = ihypo(ifn)
j1 = i1(1); j2 = i2(1)
k1 = i1(2); k2 = i2(2)
l1 = i1(3); l2 = i2(3)
i1(ifn) = ihypo(ifn) + 1
i2(ifn) = ihypo(ifn) + 1
j3 = i1(1); j4 = i2(1)
k3 = i1(2); k4 = i2(2)
l3 = i1(3); l4 = i2(3)

! Trial traction for zero velocity and zero displacement
f1 = dt * dt * area * ( mr(j1:j2,k1:k2,l1:l2) + mr(j3:j4,k3:k4,l3:l4) )
call invert( f1 )
do i = 1, 3
  t1(:,:,:,i) = t0(:,:,:,i) + f1 * dt * &
    ( ( vv(j3:j4,k3:k4,l3:l4,i) - vv(j1:j2,k1:k2,l1:l2,i) ) &
    + ( w1(j3:j4,k3:k4,l3:l4,i) - w1(j1:j2,k1:k2,l1:l2,i) ) * dt )
  t2(:,:,:,i) = t1(:,:,:,i) + f1 * &
      ( uu(j3:j4,k3:k4,l3:l4,i) - uu(j1:j2,k1:k2,l1:l2,i) )
end do

! Shear and normal traction
tn = sum( t1 * nhat, 4 )
do i = 1, 3
  t3(:,:,:,i) = t1(:,:,:,i) - tn * nhat(:,:,:,i)
end do
ts = sqrt( sum( t3 * t3, 4 ) )
tn = sum( t2 * nhat, 4 )
if ( faultopening == 1 ) tn = min( 0., tn )

! Slip-weakening friction law
f1 = mud
where ( sl < dc ) f1 = f1 + ( 1. - sl / dc ) * ( mus - mud )
f1 = -min( 0., tn ) * f1 + co

! Nucleation
if ( rcrit > 0. .and. vrup > 0. ) then
  f2 = 1.
  if ( trelax > 0. ) f2 = min( ( tm - rhypo / vrup ) / trelax, 1. )
  f2 = ( 1. - f2 ) * ts + f2 * ( -tn * mud + co )
  where ( rhypo < min( rcrit, tm * vrup ) .and. f2 < f1 ) f1 = f2
end if

! Shear traction bounded by friction
f2 = 1.
where ( ts > f1 ) f2 = f1 / ts
do i = 1, 3
  t3(:,:,:,i) = f2 * t3(:,:,:,i)
end do
ts = min( ts, f1 )

! Total traction
do i = 1, 3
  t1(:,:,:,i) = t3(:,:,:,i) + tn * nhat(:,:,:,i)
end do

! Update acceleration
do i = 1, 3
  f2 = area * ( t1(:,:,:,i) - t0(:,:,:,i) )
  w1(j1:j2,k1:k2,l1:l2,i) = w1(j1:j2,k1:k2,l1:l2,i) + f2 * mr(j1:j2,k1:k2,l1:l2)
  w1(j3:j4,k3:k4,l3:l4,i) = w1(j3:j4,k3:k4,l3:l4,i) - f2 * mr(j3:j4,k3:k4,l3:l4)
end do
call vectorbc( w1, bc1, bc2, i1bc, i2bc )

! Friction + fracture energy
t2 = vv(j3:j4,k3:k4,l3:l4,:) - vv(j1:j2,k1:k2,l1:l2,:)
f2 = sum( t1 * t2, 4 ) * area
call scalar_set_halo( f2, 0., i1core, i2core )
efric = efric + dt * sum( f2 )

! Strain energy
t2 = uu(j3:j4,k3:k4,l3:l4,:) - uu(j1:j2,k1:k2,l1:l2,:)
f2 = sum( ( t0 + t1 ) * t2, 4 ) * area
call scalar_set_halo( f2, 0., i1core, i2core )
estrain = .5 * sum( f2 )

! Moment
f2 = muf * area * sqrt( sum( t2 * t2, 4 ) )
call scalar_set_halo( f2, 0., i1core, i2core )
moment = sum( f2 )

! Slip acceleration
t2 = w1(j3:j4,k3:k4,l3:l4,:) - w1(j1:j2,k1:k2,l1:l2,:)
f2 = sqrt( sum( t2 * t2, 4 ) )

! Output
p => pio0
do while( associated( p%next ) )
  p => p%next
  call rio4( 'out', 't1',   t1(:,:,:,1) )
  call rio4( 'out', 't2',   t1(:,:,:,2) )
  call rio4( 'out', 't3',   t1(:,:,:,3) )
  call rio4( 'out', 'fr',   f1          )
  call rio4( 'out', 'tn',   tn          )
  call rio4( 'out', 'sa1',  t2(:,:,:,1) )
  call rio4( 'out', 'sa2',  t2(:,:,:,2) )
  call rio4( 'out', 'sa3',  t2(:,:,:,3) )
  call rio4( 'out', 'sam',  f2          )
  call rio4( 'out', 'ts1',  t3(:,:,:,1) )
  call rio4( 'out', 'ts2',  t3(:,:,:,2) )
  call rio4( 'out', 'ts3',  t3(:,:,:,2) )
  call rio4( 'out', 'tsm',  ts          )
end do

end subroutine

end module

