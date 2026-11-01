function out = wing_dimensions_ph(p)
%WING_DIMENSIONS_PH Solve S, cr, ct using the calculator's PH algorithm.
%   out = wing_dimensions_ph() uses alpha = 3 deg and taper = 0.8.
%   out = wing_dimensions_ph(p) overrides any named input field below.
%
%   Input units: gf, km/h, mm, deg, kg/m^3, K. Internal units: SI, rad.
%   S, cr and ct always describe ONE physical panel.
%   arFactor = 1: panel AR = b^2/S (default reference model).
%   arFactor = 2: hypothetical mirrored planar wing AR = 2*b^2/S.
%   No e = 0.8 factor is inserted in the Polhamus-Helmbold formula.
%   Numerical agreement is not experimental aerodynamic validation.

def = struct('targetGf',87.5,'speedKmh',150,'spanMm',150,...
    'taper',0.8,'alphaDeg',3,'dihedralDeg',45,...
    'sweepLeDeg',20,'rho',1.225,'temperatureK',288.15,...
    'arFactor',1);
if nargin == 0, p = struct(); end
if ~isstruct(p) || ~isscalar(p)
    error('WingPH:Input','Input must be a scalar struct.');
end
unknown = setdiff(fieldnames(p),fieldnames(def));
if ~isempty(unknown)
    error('WingPH:Input','Unknown input field: %s.',strjoin(unknown,', '));
end
names = fieldnames(def);
for j = 1:numel(names)
    key = names{j};
    if ~isfield(p,key), p.(key) = def.(key); end
    validateattributes(p.(key),{'numeric'},...
        {'real','finite','scalar'},mfilename,key);
    p.(key) = double(p.(key));
end
if any([p.targetGf,p.speedKmh,p.spanMm,p.rho,p.temperatureK] <= 0)
    error('WingPH:Input','Force, speed, span, density and temperature must be positive.');
end
if p.taper <= 0 || p.taper > 1
    error('WingPH:Input','Taper must satisfy 0 < taper <= 1.');
end
if p.alphaDeg <= 0 || p.alphaDeg >= 90 || abs(p.dihedralDeg) >= 90
    error('WingPH:Input','Require 0 < alpha < 90 deg and abs(dihedral) < 90 deg.');
end
if abs(p.sweepLeDeg) >= 89 || ~ismember(p.arFactor,[1,2])
    error('WingPH:Input','Require abs(LE sweep) < 89 deg and arFactor = 1 or 2.');
end

% 1. Unit conversions and freestream conditions.
g0 = 9.80665; R = 287.05287;
V = p.speedKmh/3.6; b = p.spanMm/1000;
Ft = p.targetGf*g0/1000;
soundSpeed = sqrt(1.4*R*p.temperatureK);
M = V/soundSpeed;
if M >= 1, error('WingPH:Mach','The model requires Mach < 1.'); end
beta2 = 1-M*M; beta = sqrt(beta2);
q = 0.5*p.rho*V*V; kap = p.arFactor;
alpha = deg2rad(p.alphaDeg); gamma = deg2rad(p.dihedralDeg);
alphaG = atan2(sin(alpha)*cos(gamma),cos(alpha));

% 2. Reduce the inverse force equation to a quadratic in A = AR_model.
t = tan(deg2rad(p.sweepLeDeg));
k = kap*(1-p.taper)/(1+p.taper);
K = 2*pi*q*kap*b*b*alphaG*cos(gamma);
if ~isfinite(K) || K <= 0
    error('WingPH:Range','Invalid force scale for this numerical range.');
end
d = beta2+t*t;
Astar = max(0,t*k/d);
forceAtA = @(A) K/(2+hypot(2,hypot(beta*A,t*A-k)));
Fmax = forceAtA(Astar); F0 = forceAtA(0);
if Ft > Fmax*(1+1e-12)
    error('WingPH:NoRoot','Target force exceeds the mathematical model bound.');
end
h = K/Ft-2;
h2minus4 = (h-2)*(h+2);       % More stable than h^2-4 near h = 2.
cq = k*k-h2minus4;
delta = d*h2minus4-beta2*k*k; % Quarter discriminant: (t*k)^2-d*cq.
scale = max([1,abs(d*h2minus4),beta2*k*k]);
if h < 2-1e-12 || delta < -1e-12*scale
    error('WingPH:NoRoot','No finite real candidate in this model.');
end
if abs(delta) <= 64*eps*scale
    delta = 0;
else
    delta = max(0,delta);
end

% 3. Stable roots of d*A^2 - 2*t*k*A + cq = 0.
sigma = 1; if t*k < 0, sigma = -1; end
Q = t*k+sigma*sqrt(delta);
if Q == 0
    candidates = t*k/d;
else
    candidates = [Q/d,cq/Q];
end

% 4. Filter roots and forward-substitute into the ORIGINAL PH force model.
accepted = []; rows = [];
for A = candidates
    if ~isfinite(A) || A <= 0, continue; end
    if any(abs(A-accepted) <= 1e-10*max(A,accepted)), continue; end
    S = kap*b*b/A;
    cr = 2*S/(b*(1+p.taper)); ct = p.taper*cr;
    tanHalf = t+(ct-cr)/(2*b);
    tanTE = t+(ct-cr)/b;
    aPH = 2*pi*A/(2+hypot(2,hypot(beta*A,A*tanHalf)));
    CL = aPH*alphaG;
    Lz = q*S*CL*cos(gamma);
    residual = Lz-Ft; relative = abs(residual)/Ft;
    row = [S,S*1e4,cr*1000,ct*1000,A,b*b/S,...
        rad2deg(atan(tanHalf)),rad2deg(atan(tanTE)),...
        aPH,CL,Lz,Lz*1000/g0,residual,relative];
    if any(~isfinite(row)) || relative > 1e-8, continue; end
    rows(end+1,:) = row; %#ok<AGROW>
    accepted(end+1) = A; %#ok<AGROW>
end
if isempty(rows)
    error('WingPH:NoFiniteRoot','No positive finite root passes the forward check.');
end
rows = sortrows(rows,1);
roots = array2table(rows,'VariableNames',...
    {'S_m2','S_cm2','cr_mm','ct_mm','A_model','AR_panel',...
     'SweepHalf_deg','SweepTE_deg','a_per_rad','CL',...
     'Lz_N','Lz_gf','Residual_N','RelativeResidual'});

% 5. Return all valid branches, diagnostic quantities and model notes.
notes = {};
if height(roots) > 1
    notes{end+1} = 'Two positive roots: smaller area does not establish an optimum.';
end
if kap == 2
    notes{end+1} = 'Mirrored planar-wing reference; X-wing interference is unvalidated.';
end
if rad2deg(alphaG) > 10
    notes{end+1} = 'Large section angle: check the linear attached-flow assumption.';
end
if roots.A_model(1) < 2
    notes{end+1} = 'Low aspect ratio: verify the aerodynamic prediction with 3D evidence.';
end
out = struct(); out.inputs = p; out.roots = roots;
out.flow = struct('V_ms',V,'q_Pa',q,'soundSpeed_ms',soundSpeed,...
    'Mach',M,'beta',beta,'alpha_g_deg',rad2deg(alphaG));
out.coefficients = struct('t',t,'k',k,'K_N',K,'d',d,'h',h,...
    'cq',cq,'delta',delta,'Q',Q);
out.limits = struct('Fmax_N',Fmax,'F0_N',F0,'Astar',Astar,...
    'attainedAtFiniteArea',Astar > 0);
out.notes = notes;
end
