%% integrateForwardDynamics_SoT
%  This is the main program for integrating the forward dynamics of the robot iCub in matlab.
%  It integrates the robot state defined in forwardDynamics_SoT.m and the user can set 
%  how many feet are on the ground, decide if activate the robot's movements, 
%  plot forces, torques and joints variables, and activate a demo of the
%  robot's movements.
clear all
close all
clc

%% Initialize the mexWholeBodyModel
wbm_modelInitialise('icubGazeboSim');

%% Setup params for balancing controller
params.demo_movements           =  1;                                      %either 0 or 1; only for two feet on the ground
params.use_QPsolver             =  0;                                      %either 0 or 1
params.use_Orientation          =  1;                                      %either 0 or 1
 
% balancing on two feet or one foot
params.feet_on_ground           =  [1,1];                                  %either 0 or 1; [left,right]

% allows the visualization of torques, forces and other user-defined graphics 
params.visualizer_graphics      =  1;                                      %either 0 or 1
params.visualizer_demo          =  1;                                      %either 0 or 1
params.visualizer_jointsPos     =  0;                                      %either 0 or 1; only if visualizer_graphics = 1
 
%% Setup general params
% this is assuming a 25DoF iCub
params.ndof         = 25;

% initial conditions                  
params.leftArmInit  = [ -20   30  0.0  45   0.0]';          
params.rightArmInit = [ -20   30  0.0  45   0.0]'; 
params.torsoInit    = [ -10.0   0.0    0.0]';
 
if     params.feet_on_ground(1) == 1 && params.feet_on_ground(2) == 1
     
% initial conditions for balancing on two feet 
 params.leftLegInit  = [  25.5   0.1   0.0  -18.5  -5.5  -0.1]';
 params.rightLegInit = [  25.5   0.1   0.0  -18.5  -5.5  -0.1]';

elseif   params.feet_on_ground(1) == 1 && params.feet_on_ground(2) == 0
     
% initial conditions for the robot standing on the left foot
 params.leftLegInit  = [  25.5   15.0   0.0  -18.5  -5.5  -0.1]';
 params.rightLegInit = [  25.5   5.0    0.0  -40    -5.5  -0.1]'; 
 
elseif   params.feet_on_ground(1) == 0 && params.feet_on_ground(2) == 1
  
% initial conditions for the robot standing on the right foot
 params.leftLegInit  = [  25.5   5.0    0.0  -40    -5.5  -0.1]';
 params.rightLegInit = [  25.5   15.0   0.0  -18.5  -5.5  -0.1]';
   
end
 
params.qjInit      = [params.torsoInit;params.leftArmInit;params.rightArmInit;params.leftLegInit;params.rightLegInit]*(pi/180);
params.dqjInit     = zeros(params.ndof,1);
   
params.dx_bInit    = zeros(3,1);
params.omega_bInit = zeros(3,1);
  
%% Updating the robot position
wbm_updateState(params.qjInit,params.dqjInit,[params.dx_bInit;params.omega_bInit]);

% fixing the world reference frame w.r.t. the foot on ground position
if params.feet_on_ground(1) == 1

[R_b0,x_b0] = wbm_getWorldFrameFromFixedLink('l_sole',params.qjInit);

else
    
[R_b0,x_b0] = wbm_getWorldFrameFromFixedLink('r_sole',params.qjInit);
    
end

wbm_setWorldFrame(R_b0,x_b0,[0 0 -9.81]')

[~,T_b,~,~]    = wbm_getState();
 
params.chiInit = [T_b; params.qjInit; params.dx_bInit; params.omega_bInit; params.dqjInit];

%% Contact constraints definition         
if       params.feet_on_ground(1) == 1 && params.feet_on_ground(2) == 1
 
% contact constraints for 2 feet on ground
 params.constraintLinkNames      = {'l_sole','r_sole'}; 

elseif   params.feet_on_ground(1) == 1 && params.feet_on_ground(2) == 0

% contact constraints for left foot on ground     
 params.constraintLinkNames      = {'l_sole'}; 
 
elseif   params.feet_on_ground(1) == 0 && params.feet_on_ground(2) == 1
    
% contact constraints for right foot on ground    
 params.constraintLinkNames      = {'r_sole'};

end

 params.numConstraints           = length(params.constraintLinkNames);
   
%% Momentum jacobian and linearization of angular momentum integral
% momentum jacobian at the eq. point
Jw_b0               = zeros(6,6);
Jw_j0               = zeros(6,params.ndof);
Jc0                 = zeros(6*params.numConstraints,params.ndof+6);

for ii = 1:6
    
Nu_base         = zeros(6,1);
Nu_base(ii)     = 1;

Jw_b0(:,ii)     = wbm_centroidalMomentum(R_b0, x_b0, params.qjInit, zeros(params.ndof,1), Nu_base);
 
end

for ii = 1:params.ndof

dqj_Jw         = zeros(params.ndof,1);
dqj_Jw(ii)     = 1;

Jw_j0(:,ii)    = wbm_centroidalMomentum(R_b0, x_b0, params.qjInit, dqj_Jw, zeros(6,1));

end

% contacts jacobian at the eq. point
for i=1:params.numConstraints
    
    Jc0(6*(i-1)+1:6*i,:) = wbm_jacobian(R_b0,x_b0,params.qjInit,params.constraintLinkNames{i});
    
end
 
Jw0  =  Jw_j0 -Jw_b0*(eye(6)/Jc0(1:6,1:6))*Jc0(1:6,7:end);

% angular momentum integral linearization
params.linAngInt  = Jw0(4:end,:);

% parameters for the new postural task
params.M0         = wbm_massMatrix(R_b0,x_b0,params.qjInit);
params.Jc0        = Jc0;

%% Others parameters for balancing controller
 [jl1,jl2]        = wbm_jointLimits();
 limits           = [jl1 jl2];
 params.limits    = limits;
 params.CoM_ini   = wbm_forwardKinematics('com');
 
 params.lfoot_ini = wbm_forwardKinematics('l_sole');
 params.rfoot_ini = wbm_forwardKinematics('r_sole');
 
%% Setup integration
 plot_set
 
 params.tStart   = 0;
 params.tEnd     = 20;   
 params.sim_step = 0.01;
 params.wait     = waitbar(0,'State integration in progress...');

 forwardDynFunc  = @(t,chi)forwardDynamics_SoT(t,chi,params);
    
%% Integrate forward dynamics
if params.demo_movements == 0 

  options = odeset('RelTol',1e-3,'AbsTol', 1e-4);

else

  options = odeset('RelTol',1e-6,'AbsTol',1e-6);

end   

 [t,chi] = ode15s(forwardDynFunc,params.tStart:params.sim_step:params.tEnd,params.chiInit,options);

 delete(params.wait)       
 
%% Visualize forward dynamics
params.wait     = waitbar(0,'Graphics generation in progress...');

visualizer_SoT(t,chi,params)

delete(params.wait)
   