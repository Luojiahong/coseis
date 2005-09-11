%------------------------------------------------------------------------------%
% PML

% Check Courant stability condition. TODO: check, make general
courant = dt * matmax(2) * sqrt( 3 ) / dx;
fprintf( '  Courant: 1 >%11.4e\n', courant )

% PML damping
if npml
  c1 =  8. / 15.;
  c2 = -3. / 100.;
  c3 =  1. / 1500.;
  tune = 3.5;
  pmlp = 2.;
  hmean = 2. * matmin .* matmax ./ ( matmin + matmax );
  damp = tune * hmean(3) / dx * ( c1 + ( c2 + c3 * npml ) * npml ) / npml^pmlp;
  for i = 1:npml
    dampn = damp *   i ^ pmlp;
    dampc = damp * ( i ^ pmlp + ( i - 1 ) ^ pmlp ) / 2.;
    dn1(npml-i+1) = - 2. * dampn        / ( 2. + dt * dampn );
    dc1(npml-i+1) = ( 2. - dt * dampc ) / ( 2. + dt * dampc );
    dn2(npml-i+1) =   2.                / ( 2. + dt * dampn );
    dc2(npml-i+1) =   2. * dt           / ( 2. + dt * dampc );
  end
end

