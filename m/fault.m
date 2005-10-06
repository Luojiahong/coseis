%------------------------------------------------------------------------------%
% Fault calculations

if ~ifn; return; end

if init

init = 0;
fprintf( 'Initialize fault\n' )

% Input
mus(:) = 0.;
mud(:) = 0.;
dc(:) = 0.;
co(:) = 1e9;
t1(:) = 0.;
t2(:) = 0.;
t3(:) = 0.;

for iz = 1:nin
if ( readfile(iz) )
  i1 = i1node;
  i2 = i2node;
  i1(ifn) = 1;
  i2(ifn) = 1;
  j1 = i1(1); j2 = i2(1);
  k1 = i1(2); k2 = i2(2);
  l1 = i1(3); l2 = i2(3);
  endian = textread( 'data/endian', '%c', 1 );
  switch fieldin(iz)
  case 'mus', mus(j1:j2,k1:k2,l1:l2)  = bread( 'data/mus', endian );
  case 'mud', mud(j1:j2,k1:k2,l1:l2)  = bread( 'data/mud', endian );
  case 'dc',  dc(j1:j2,k1:k2,l1:l2)   = bread( 'data/dc',  endian );
  case 'co',  co(j1:j2,k1:k2,l1:l2)   = bread( 'data/co',  endian );
  case 'sxx', t1(j1:j2,k1:k2,l1:l2,1) = bread( 'data/sxx', endian );
  case 'syy', t1(j1:j2,k1:k2,l1:l2,2) = bread( 'data/syy', endian );
  case 'szz', t1(j1:j2,k1:k2,l1:l2,3) = bread( 'data/szz', endian );
  case 'syz', t2(j1:j2,k1:k2,l1:l2,1) = bread( 'data/syz', endian );
  case 'szx', t2(j1:j2,k1:k2,l1:l2,2) = bread( 'data/szx', endian );
  case 'sxy', t2(j1:j2,k1:k2,l1:l2,3) = bread( 'data/sxy', endian );
  case 'tn',  t3(j1:j2,k1:k2,l1:l2,1) = bread( 'data/tn',  endian );
  case 'th',  t3(j1:j2,k1:k2,l1:l2,2) = bread( 'data/th',  endian );
  case 'td',  t3(j1:j2,k1:k2,l1:l2,3) = bread( 'data/td',  endian );
  end
else
  [ i1, i2 ] = zone( i1in(iz,:), i2in(iz,:), nn, nnoff, ihypo, ifn );
  i1(ifn) = 1;
  i2(ifn) = 1;
  j1 = i1(1); j2 = i2(1);
  k1 = i1(2); k2 = i2(2);
  l1 = i1(3); l2 = i2(3);
  switch fieldin(iz)
  case 'mus', mus(j1:j2,k1:k2,l1:l2)  = inval(iz);
  case 'mud', mud(j1:j2,k1:k2,l1:l2)  = inval(iz);
  case 'dc',  dc(j1:j2,k1:k2,l1:l2)   = inval(iz);
  case 'co',  co(j1:j2,k1:k2,l1:l2)   = inval(iz);
  case 'sxx', t1(j1:j2,k1:k2,l1:l2,1) = inval(iz);
  case 'syy', t1(j1:j2,k1:k2,l1:l2,2) = inval(iz);
  case 'szz', t1(j1:j2,k1:k2,l1:l2,3) = inval(iz);
  case 'syz', t2(j1:j2,k1:k2,l1:l2,1) = inval(iz);
  case 'szx', t2(j1:j2,k1:k2,l1:l2,2) = inval(iz);
  case 'sxy', t2(j1:j2,k1:k2,l1:l2,3) = inval(iz);
  case 'tn',  t3(j1:j2,k1:k2,l1:l2,1) = inval(iz);
  case 'th',  t3(j1:j2,k1:k2,l1:l2,2) = inval(iz);
  case 'td',  t3(j1:j2,k1:k2,l1:l2,3) = inval(iz);
  end
end
end

% Lock fault in PML region
i1 = i1pml + 1;
i2 = i2pml - 1;
i1(ifn) = 1;
i2(ifn) = 1;
j1 = i1(1); j2 = i2(1);
k1 = i1(2); k2 = i2(2);
l1 = i1(3); l2 = i2(3);
f1 = co;
co = 1e9;
co(j1:j2,k1:k2,l1:l2) = f1(j1:j2,k1:k2,l1:l2);

% Normal vectors
side = sign( faultnormal );
i1 = i1node;
i2 = i2node;
i1(ifn) = ihypo(ifn);
i2(ifn) = ihypo(ifn);
nhat = snormals( x, i1, i2 );
area = sqrt( sum( nhat .* nhat, 4 ) );
f1 = area;
ii = f1 ~= 0.;
f1(ii) = side ./ f1(ii);
for i = 1:3
  nhat(:,:,:,i) = nhat(:,:,:,i) .* f1;
end

% Resolve prestress onto fault
for i = 1:3
  j = mod( i , 3 ) + 1;
  k = mod( i + 1, 3 ) + 1;
  t0(:,:,:,i) = ...
    t1(:,:,:,i) .* nhat(:,:,:,i) + ...
    t2(:,:,:,j) .* nhat(:,:,:,k) + ...
    t2(:,:,:,k) .* nhat(:,:,:,j);
end

% Stike vectors
t1(:,:,:,1) = nhat(:,:,:,2) .* upvector(3) - nhat(:,:,:,3) .* upvector(2);
t1(:,:,:,2) = nhat(:,:,:,3) .* upvector(1) - nhat(:,:,:,1) .* upvector(3);
t1(:,:,:,3) = nhat(:,:,:,1) .* upvector(2) - nhat(:,:,:,2) .* upvector(1);
f1 = sqrt( sum( t1 .* t1, 4 ) );
ii = f1 ~= 0.;
f1(ii) = 1. ./ f1(ii);
for i = 1:3
  t1(:,:,:,i) = t1(:,:,:,i) .* f1;
end

% Dip vectors
t2(:,:,:,1) = nhat(:,:,:,2) .* t1(:,:,:,3) - nhat(:,:,:,3) .* t1(:,:,:,2);
t2(:,:,:,2) = nhat(:,:,:,3) .* t1(:,:,:,1) - nhat(:,:,:,1) .* t1(:,:,:,3);
t2(:,:,:,3) = nhat(:,:,:,1) .* t1(:,:,:,2) - nhat(:,:,:,2) .* t1(:,:,:,1);
f1 = sqrt( sum( t1 .* t1, 4 ) );
ii = f1 ~= 0.;
f1(ii) = 1. ./ f1(ii);
for i = 1:3
  t2(:,:,:,i) = t2(:,:,:,i) .* f1;
end

% Total pretraction
for i = 1:3
  t0(:,:,:,i) = t0(:,:,:,i) + ...
    t3(:,:,:,1) .* nhat(:,:,:,i) + ...
    t3(:,:,:,2) .* t1(:,:,:,i) + ...
    t3(:,:,:,3) .* t2(:,:,:,i);
end

% Hypocentral radius
i1 = [ 1 1 1 ];
i2 = nm;
i1(ifn) = ihypo(ifn);
i2(ifn) = ihypo(ifn);
j1 = i1(1); j2 = i2(1);
k1 = i1(2); k2 = i2(2);
l1 = i1(3); l2 = i2(3);
for i = 1:3
  t3(:,:,:,i) = x(j1:j2,k1:k2,l1:l2,i) - xhypo(i);
end
r = sqrt( sum( t3 .* t3, 4 ) );

% Metadata
i1 = ihypo;
i1(ifn) = 1;
j = i1(1);
k = i1(2);
l = i1(3);
mus0 = mus(j,k,l);
mud0 = mud(j,k,l);
dc0 = dc(j,k,l);
tn0 = sum( t0(j,k,l,:) .* nhat(j,k,l,:) );
ts0 = sqrt( sum( shiftdim( t0(j,k,l,:) - tn0 * nhat(j,k,l,:) ) ) );
tn0 = max( -tn0, 0 );
s = ( tn0 * mus0 - ts0 ) / ( ts0 - tn0 * mud0 );
lc =  dc0 * ( rho * vs * vs ) / tn0 / ( mus0 - mud0 );
rctest = rho * vs * vs * tn0 * ( mus0 - mud0 ) * dc0 ...
  / ( ts0 - tn0 * mud0 ) ^ 2.;
fid = fopen( 'out/faultmeta.m', 'w' );
fprintf( fid, 'mus0   = %g; % static friction at hypocenter \n', mus0   );
fprintf( fid, 'mud0   = %g; % dynamic friction at hypocenter\n', mud0   );
fprintf( fid, 'dc0    = %g; % dc at hypocenter\n',               dc0    );
fprintf( fid, 'tn0    = %g; % normal traction at hypocenter\n',  tn0    );
fprintf( fid, 'ts0    = %g; % shear traction at hypocenter\n',   ts0    );
fprintf( fid, 's      = %g; % strength paramater\n',             s      );
fprintf( fid, 'lc     = %g; % breakdown width\n',                lc     );
fprintf( fid, 'rctest = %g; % rcrit for spontaneous rupture \n', rctest );
close( fid )
return

end

%------------------------------------------------------------------------------%

% Indices
i1 = [ 1 1 1 ];
i2 = nm;
i1(ifn) = ihypo(ifn);
i2(ifn) = ihypo(ifn);
j1 = i1(1); j2 = i2(1);
k1 = i1(2); k2 = i2(2);
l1 = i1(3); l2 = i2(3);
i1(ifn) = ihypo(ifn) + 1;
i2(ifn) = ihypo(ifn) + 1;
j3 = i1(1); j4 = i2(1);
k3 = i1(2); k4 = i2(2);
l3 = i1(3); l4 = i2(3);

% Zero slip velocity boundary condition
f1 = dt * area .* ( mr(j1:j2,k1:k2,l1:l2) + mr(j3:j4,k3:k4,l3:l4) );
ii = f1 ~= 0.;
f1(ii) = 1 ./ f1(ii);
for i = 1:3
  t3(:,:,:,i) = t0(:,:,:,i) + f1 .* side .* ...
    ( v(j3:j4,k3:k4,l3:l4,i) + dt .* w1(j3:j4,k3:k4,l3:l4,i) ...
    - v(j1:j2,k1:k2,l1:l2,i) - dt .* w1(j1:j2,k1:k2,l1:l2,i) );
end

% Decompose traction to normal and sear components
tn = sum( t3 .* nhat, 4 );
if any( tn > 0. ), fprintf( 'fault opening!\n' ), end
for i = 1:3
  t1(:,:,:,i) = tn .* nhat(:,:,:,i);
end
t2 = t3 - t1;
ts = sqrt( sum( t2 .* t2, 4 ) );

% Slip-weakening friction Law
ii = tn > 0.;
tn(ii) = 0.;
f1 = mud;
ii = sl < dc;
f1(ii) = f1(ii) + ( 1. - sl(ii) ./ dc(ii) ) .* ( mus(ii) - mud(ii) );
f1 = -tn .* f1 + co;

% Nucleation
if rcrit > 0. && vrup > 0.
  f2(:) = 1.;
  if nramp, f2 = min( ( t - r / vrup ) / trelax, 1. ); end
  f2 = ( 1. - f2 ) .* ts + f2 .* ( -tn .* mud + co);
  ii = r < min( rcrit, t * vrup ) & f2 < f1;
  f1(ii) = f2(ii);
end

% Shear traction bounded by friction
f2(:) = 1.;
ii = ts > f1;
f2(ii) = f1(ii) ./ ts(ii);

% Update acceleration
for i = 1:3
f1 = area .* side .* ( t1(:,:,:,i) + f2 .* t2(:,:,:,i) - t0(:,:,:,i) );
w1(j1:j2,k1:k2,l1:l2,i) = w1(j1:j2,k1:k2,l1:l2,i) + f1 .* mr(j1:j2,k1:k2,l1:l2);
w1(j3:j4,k3:k4,l3:l4,i) = w1(j3:j4,k3:k4,l3:l4,i) - f1 .* mr(j3:j4,k3:k4,l3:l4);
end

