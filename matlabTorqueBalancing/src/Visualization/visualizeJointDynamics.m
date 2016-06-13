function ContFig = visualizeJointDynamics(t,config,qj,qjRef)
%VISUALIZEJOINTDYNAMICS visualizes the joint space dynamics of the iCub robot
%                       from forward dynamics integration.
%
%   ContFig = VISUALIZEJOINTDYNAMICS(t,config,qj,qjRef) takes as inputs the
%   integration time T, a structure CONFIG which contains all the utility
%   parameters, the joint position QJ and the desired joint position QJREF.
%   The output is a counter for the automatic correction of figures numbers
%   in case a new figure is added.
%
% Author : Gabriele Nava (gabriele.nava@iit.it)
% Genova, May 2016
%

% ------------Initialization----------------
% setup parameters
ContFig  = config.ContFig;

%% Joints dynamics
for k=1:5
  
% LEFT ARM    
figure(ContFig)
subplot(3,2,k)
plot(t,qj(k+3,:))
hold on
plot(t,qjRef(k+3,:),'k')
grid on
xlabel('Time [s]')
ylabel('Angle [rad]')
name = whatname('left_arm',k);
title(name)
legend('qj','qjRef')

% RIGHT ARM
figure(ContFig+1)
subplot(3,2,k)
plot(t,qj(k+3+5,:))
hold on
plot(t,qjRef(k+3+5,:),'k')
grid on
xlabel('Time [s]')
ylabel('Angle [rad]')
name = whatname('right_arm',k);
title(name)
legend('qj','qjRef')
end

ContFig = ContFig +2;

for k=1:6

% LEFT LEG
figure(ContFig)
subplot(3,2,k)
plot(t,qj(k+13,:))
hold on
plot(t,qjRef(k+13,:),'k')
grid on
xlabel('Time [s]')
ylabel('Angle [rad]')
name = whatname('left_leg',k);
title(name)
legend('qj','qjRef')

% RIGHT LEG
figure(ContFig+1)
subplot(3,2,k)
plot(t,qj(k+13+6,:))
hold on
plot(t,qjRef(k+13+6,:),'k')
grid on
xlabel('Time [s]')
ylabel('Angle [rad]')
name = whatname('right_leg',k);
title(name)
legend('qj','qjRef')
end

ContFig = ContFig +2;

for k=1:3
    
% TORSO
figure(ContFig)
subplot(3,1,k)
plot(t,qj(k,:))
hold on
plot(t,qjRef(k,:),'k')
grid on
xlabel('Time [s]')
ylabel('Angle [rad]')
name = whatname('torso',k);
title(name)
legend('qj','qjRef')
end

ContFig = ContFig +1;

end