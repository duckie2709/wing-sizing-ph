% CHAY_TINH_CANH_PH - Mo file nay trong MATLAB va bam Run (F5).
% Sua cac gia tri trong wingPH_params de tinh bo thong so khac.
% Khong can Optimization Toolbox. S, cr, ct thuoc MOT tam canh.
addpath(fileparts(mfilename('fullpath')));

wingPH_params = struct(...
    'targetGf',87.5,...       % Thanh phan luc dung moi tam, gf.
    'speedKmh',150,...       % Van toc, km/h.
    'spanMm',150,...         % Sai thuc goc-dau trong mat phang tam, mm.
    'taper',0.8,...          % ct/cr.
    'alphaDeg',3,...         % Goc tan than, deg.
    'dihedralDeg',45,...     % Dihedral, deg; co the nhap -45.
    'sweepLeDeg',20,...      % Sweep mep truoc trong mat phang tam, deg.
    'rho',1.225,...          % Mat do khong khi, kg/m^3.
    'temperatureK',288.15,...% Nhiet do, K.
    'arFactor',1);           % 1: mot tam; 2: canh phang phan chieu gia dinh.

wingPH_result = wing_dimensions_ph(wingPH_params);
disp(wingPH_result.roots(:,{'S_cm2','cr_mm','ct_mm',...
    'A_model','SweepTE_deg','Lz_gf','RelativeResidual'}));

fprintf('alpha_g = %.8f deg; q = %.6f Pa; Mach = %.8f\n',...
    wingPH_result.flow.alpha_g_deg,wingPH_result.flow.q_Pa,...
    wingPH_result.flow.Mach);
for wingPH_noteIndex = 1:numel(wingPH_result.notes)
    fprintf('Model note: %s\n',wingPH_result.notes{wingPH_noteIndex});
end

% Vi du goi ham truc tiep va chi thay hai thong so:
% r = wing_dimensions_ph(struct('alphaDeg',4,'taper',0.7));
% disp(r.roots)
%
% Neu can xuat bang ket qua, bo dau % cua dong duoi:
% writetable(wingPH_result.roots,'ket_qua_canh_PH.csv');
