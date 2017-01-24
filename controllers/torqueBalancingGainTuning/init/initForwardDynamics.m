function [] = initForwardDynamics(CONFIG)
%INITFORWARDDYNAMICS setups the forward dynamics integration of the robot 
%                    iCub using MATLAB.
%
% [] = INITFORWARDDYNAMICS(CONFIG) takes as input the structure CONFIG 
% containing all the configuration parameters. It has no output. The 
% forward dynamics integration will be performed following the options 
% the user specified in the initialization file.
%
% Author : Gabriele Nava (gabriele.nava@iit.it)
% Genova, May 2016
%

% ------------Initialization----------------
%% Setup the configuration and state parameters
feet_on_ground               = CONFIG.feet_on_ground;
ndof                         = CONFIG.ndof;
qjInit                       = CONFIG.qjInit;
dqjInit                      = zeros(ndof,1);
dx_bInit                     = zeros(3,1);
w_omega_bInit                = zeros(3,1);

%% Contact constraints definition
if sum(feet_on_ground) == 2
    
    CONFIG.constraintLinkNames = {'l_sole','r_sole'};
    
elseif feet_on_ground(1) == 1 && feet_on_ground(2) == 0
    
    CONFIG.constraintLinkNames = {'l_sole'};
    
elseif feet_on_ground(1) == 0 && feet_on_ground(2) == 1
    
    CONFIG.constraintLinkNames = {'r_sole'};
end

CONFIG.numConstraints = length(CONFIG.constraintLinkNames);

%% Configure the model using initial conditions
wbm_updateState(qjInit,dqjInit,[dx_bInit;w_omega_bInit]);

% fixing the world reference frame w.r.t. the foot on ground position
if  feet_on_ground(1) == 1
    
    [w_R_bInit,x_bInit] = wbm_getWorldFrameFromFixedLink('l_sole',qjInit);
else
    [w_R_bInit,x_bInit] = wbm_getWorldFrameFromFixedLink('r_sole',qjInit);
end

wbm_setWorldFrame(w_R_bInit,x_bInit,[0 0 -9.81]')

% initial state (floating base + joints)
[~,basePoseInit,~,~]          = wbm_getState();
chiInit                       = [basePoseInit; qjInit; dx_bInit; w_omega_bInit; dqjInit];

%% Initial gains
% the initial gains are defined before the numerical integration
CONFIG.gainsInit              = gains(CONFIG);

%% Initial dynamics and forward kinematics
% initial state
CONFIG.initState              = robotState(chiInit,CONFIG);

% joint references and initial state with inverse kinematics
if CONFIG.jointRef_with_ikin == 1
    
    [CONFIG.IKIN,chiInit,CONFIG.figureCont]  = initInverseKinematics(CONFIG);
    CONFIG.initState                         = robotState(chiInit,CONFIG);
end

% initial dynamics
CONFIG.initDynamics           = robotDynamics(CONFIG.initState,CONFIG);
% initial forward kinematics
CONFIG.initForKinematics      = robotForKinematics(CONFIG.initState,CONFIG.initDynamics);

%% %%%%%%%%%%%%% LINEARIZATION DEBUG AND STABILITY ANALYSIS %%%%%%%%%%%% %%
if CONFIG.linearizationDebug == 1
    
    % the initial configuration is changed by a small delta, but the references
    % are not updated. In this way the robot will move to the reference position
    delta        = 1;
    qjInit(1:13) = qjInit(1:13)-delta*pi/180;
    
    wbm_updateState(qjInit,dqjInit,[dx_bInit;w_omega_bInit]);
    
    % fixing the world reference frame w.r.t. the foot on ground position
    if  feet_on_ground(1) == 1
    
        [w_R_bInit,x_bInit] = wbm_getWorldFrameFromFixedLink('l_sole',qjInit);
    else
        [w_R_bInit,x_bInit] = wbm_getWorldFrameFromFixedLink('r_sole',qjInit);
    end
    
    wbm_setWorldFrame(w_R_bInit,x_bInit,[0 0 -9.81]')
    
   [~,basePoseInit,~,~]          = wbm_getState();
   chiInit                       = [basePoseInit; qjInit; dx_bInit; w_omega_bInit; dqjInit];

    CONFIG.initState             = robotState(chiInit,CONFIG);
    CONFIG.initDynamics          = robotDynamics(CONFIG.initState,CONFIG);
    CONFIG.initForKinematics     = robotForKinematics(CONFIG.initState,CONFIG.initDynamics);
    
end

% the system is then linearized around the initial position, to verify the stability
CONFIG.linearization             = jointSpaceLinearization(CONFIG,qjInit);

%% Gains tuning procedure
if CONFIG.gains_tuning == 1
    
    [gainsKron,CONFIG.linearization.KS,CONFIG.linearization.KD] = gainsTuning(CONFIG.linearization,CONFIG);
    CONFIG.gain                                                 = gainsConstraints(gainsKron,CONFIG);
else
    CONFIG.gain  = CONFIG.gainsInit;
end

%% Forward dynamics integration
CONFIG.wait           = waitbar(0,'Forward dynamics integration...');
forwardDynFunc        = @(t,chi)forwardDynamics(t,chi,CONFIG);

% either fixed step integrator or ODE15s
if CONFIG.integrateWithFixedStep == 1
    [t,chi]           = euleroForward(forwardDynFunc,chiInit,CONFIG.tEnd,CONFIG.tStart,CONFIG.sim_step);
else
    [t,chi]           = ode15s(forwardDynFunc,CONFIG.tStart:CONFIG.sim_step:CONFIG.tEnd,chiInit,CONFIG.options);
end

delete(CONFIG.wait)

%% Visualize integration results and robot simulator
CONFIG.figureCont     = initVisualizer(t,chi,CONFIG);

end