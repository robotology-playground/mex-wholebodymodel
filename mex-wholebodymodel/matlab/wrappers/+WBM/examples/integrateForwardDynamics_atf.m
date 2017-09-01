% namespaces:
import WBM.*
import WBM.utilities.tfms.*
import WBM.RobotModel.iCub_arms_torso_free.*


%% Initialization of the WBM for the iCub-Robot:
wf2fixLnk        = true; % set the world frame to a fixed link
[wbm_icub, ndof] = initRobot_iCub_atf(wf2fixLnk);
wbm_icub.ndof    = ndof;
icub_model       = wbm_icub.robot_model;
icub_config      = wbm_icub.robot_config;

%% State variable:
%  Create the initial condition of the state variable "chi" for the integration of the
%  forward dynamics in state-space form. The state-space form reduces, through variable
%  substitution, the inhomogeneous second-order ODE to a first-order ODE.
%  For further details see:
%    [1] Rigid Body Dynamics Algorithms, Roy Featherstone, Springer, 2008,
%        Chapter 3, pp. 40-42, formula (3.8).
chi_init = wbm_icub.init_stvChi;

%% Control torques:
%  Setup the time-dependent function "fhTrqControl" which describes a forcing function
%  on the ODEs to control the dynamics of the equation-system. It refers to the control
%  torques of each time-step t and is needed to calculate the constraint (contact) forces
%  which influences the outcome of each equation, the generalized acceleration dv (q_ddot).
[p_b, R_b] = frame2posRotm(wbm_icub.init_vqT_base);
qj_init = icub_config.init_state_params.q_j;
g_init  = wbm_icub.generalizedBiasForces(R_b, p_b, qj_init, zeros(icub_model.ndof,1), zeros(6,1));
len = size(g_init,1);

% Function handle (fh) for the torque controller function:
% Note: This function handle has only a very simple dummy-function as controller (zero
%       torques) that works in this case. For complex scenarios it is advisable to use
%       a real controller function instead to avoid integration errors.
fhTrqControl = @(t, M, c_qv, stp, nu, Jc, djcdq, foot_conf)zeroTrqsController(size(g_init(7:len,1)));

% Configuration structure for the feet state:
% Note: The state of the feet configuration is needed for the extended forward dynamics
%       function with feet pose correction (FPC). It defines the current feet pose and
%       on which foot the legged robot is currently in contact with the ground.
feet_on_ground = [true, true]; % [l_foot, r_foot]
feet_conf = wbm_icub.configStateFeet(feet_on_ground, qj_init);

%% ODE-Solver:
%  Setup the function handle of the form f(t,chi), where chi refers to the dynamic state
%  of the system. It evaluates the right side of the nonlinear first-order ODEs of the
%  form chi' = f(t,chi) and returns a vector of rates of change (vector of derivatives)
%  which will be integrated by the solver.
ac_0 = wbm_icub.zeroCtcAcc(feet_conf);
fhFwdDyn = @(t, chi)wbm_icub.forwardDynamicsFPC(t, chi, fhTrqControl, feet_conf, ac_0);

% specifying the time interval of the integration ...
sim_time.start = 0.0;
sim_time.end   = 2.0;
sim_time.step  = 0.01;
tspan = sim_time.start:sim_time.step:sim_time.end;

disp('Start the numerical integration...');

ode_options = odeset('RelTol', 1e-3, 'AbsTol', 1e-4);         % setup the error tolerances ...
[t, chi]    = ode15s(fhFwdDyn, tspan, chi_init, ode_options); % ODE-Solver
% or, optional:
%[t, chi] = wbm_icub.intForwardDynamics(tspan, chi_init, fhTrqControl, ode_options, feet_conf, ac_0, 'fpc');

disp('Numerical integration finished.');

noi = size(chi,1);
fprintf('Number of integrations: %d\n', noi);

%% iCub-Simulator:

% setup the window and plot parameters for the WBM-simulator:
sim_config = initSimConfig_iCub_atf(icub_model.urdf_robot_name);             % shows the simulation with a light scene as default.
%sim_config = initSimConfig_iCub_atf(icub_model.urdf_robot_name, 'DarkScn'); % optional, shows the simulation with a dark scene.
sim_config = wbm_icub.setupSimulation(sim_config);
x_out = wbm_icub.getPositionsData(chi);
% show and repeat the simulation 2 times ...
nRpts = 2;
wbm_icub.simulateForwardDynamics(x_out, sim_config, sim_time.step, nRpts);

%% Plot the results -- CoM-trajectory:
wbm_icub.plotCoMTrajectory(chi);

% get the visualization data of the forward dynamics integration for plots and animations:
vis_data = wbm_icub.getFDynVisData(chi, fhTrqControl, feet_conf, ac_0, 'fpc');
