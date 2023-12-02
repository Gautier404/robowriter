% MAE C163A/C263A Project
% Team X
clc;

%% CONSTANTS

% Paper level relative to frame 0 z axis
z_paper = -70;         % mm
z_lifted = z_paper + 5; % mm

% Pen Angle
pen_angle = 129.75; % deg

% LINK LENGTHS
L2 = 140;           % mm
L3 = 140;           % mm
L4 = 40.389;        % mm
L5 = 25;            % mm  [PEN EXTENTION LENGTH]

% LINK ANGLES
% theta 2, 3, 4 are w.r.t. upward vertical axis
theta1 =  30;       % deg [EDIT]
theta2 = -30;       % deg [EDIT]
theta3 = -30 ;      % deg [EDIT]
theta4 = -30;       % deg [EDIT]
theta5 = -50.25;    % deg

%% Initialize
initialize();
input('Press any key to continue!');


%% Main

% start at zero position
% Zero();

% Move to center of paper, pen slightly lifted
%[x_curr, y_curr, z_curr] = MoveToTarget(260, 0, z_lifted, L2, L4, pen_angle);



x_target = 240;
y_target = 176;
z_target = -48;
pause(1)

theta1 = read4ByteTxRx(port_num, PROTOCOL_VERSION, 1, MX28_PRESENT_POSITION);
theta2 = read4ByteTxRx(port_num, PROTOCOL_VERSION, 2, MX28_PRESENT_POSITION);
theta3 = read4ByteTxRx(port_num, PROTOCOL_VERSION, 3, MX28_PRESENT_POSITION);
theta4 = read4ByteTxRx(port_num, PROTOCOL_VERSION, 4, MX28_PRESENT_POSITION);

theta1 = NumsToTheta(theta1);
theta2 = NumsToTheta(theta2);
theta3 = NumsToTheta(theta3);
theta4 = NumsToTheta(theta4);

theta1 = theta1 - 136.84;
theta2 = theta2 - 178.06;
theta3 = theta3 - 159.87;
theta4 = theta4 - 95.01;

T = FK(L2,L3,L4,L5,theta1,theta2,theta3,theta4,theta5);

x1_start = T(1,4);
y1_start = T(2,4);
z1_start = T(3,4);

%thetasIK = IK(x1_start, y1_start, z1_start, L2, L4, pen_angle);

%[nums, x_new, y_new, z_new] = MoveLinear(x1_start, y1_start, z1_start, x_target, y_target, z_target, L2, L4, pen_angle);

%nums
%SendMotorCommands(nums, port_num, PROTOCOL_VERSION, MX28_GOAL_POSITION);


%% Terminate
input('Press any key to terminate!');
terminate();


%% FUNCTION DEFINITIONS

%//////////////////////////////////////////////////////////////////////////////////////////////////
% FORWARD KINEMATICS - units: degrees and mm
%//////////////////////////////////////////////////////////////////////////////////////////////////
function T = FK(L2,L3,L4,L5,theta1,theta2,theta3,theta4,theta5)
    TF_1 = TF(     0,            0,         0,       theta1);
    TF_2 = TF(    90,            0,         0,     90 + theta2);
    TF_3 = TF(     0,            L2,        0,       theta3);
    TF_4 = TF(     0,            L3,        0,       theta4);
    TF_5 = TF(     0,            L4,        0,       theta5);
    TF_6 = TF(     0,            L5,        0,           0);
    
    % base to end effector T
    T = TF_1*TF_2*TF_3*TF_4*TF_5*TF_6;
end

%//////////////////////////////////////////////////////////////////////////////////////////////////
% INVERSE KINEMATICS - units: degrees and mm
%//////////////////////////////////////////////////////////////////////////////////////////////////
function thetas = IK(x_target, y_target, z_target, L2, L4, pen_angle)

    theta1_min = -55;
    theta1_max = 55;
    
    theta2_min = -115;
    theta2_max = 0;
    
    theta3_min = -108;
    theta3_max = 0;
    
    theta4_min = -103;
    theta4_max = 103;

    % This is an offset target that frame 4 should reach
    x = 0;      % recalculated later
    y = y_target;
    z = z_target + L4*sind(pen_angle-90) + 25;
    
    % Link 1 simply needs to point in the direction of the target
    theta1 = atan2d(y_target, x_target);
    
    % Recalculate the adjusted offset target x & y coordinates based on theta1 angle
    x = x_target - (L4 * cosd(pen_angle-90)*abs(cosd(theta1)));
    if theta1 > 0
        y = y_target - (L4 * cosd(pen_angle-90)*abs(sind(theta1)));
    elseif theta1 < 0
        y = y_target + (L4 * cosd(129.75-90)*abs(sind(theta1)));
    end
    
    % straight-line distance to adjusted target, used for calculations below
    L = sqrt(x^2+y^2+z^2);
    
    % The rest is purely geometrically derived
    theta2 = (90 - ( acosd(L/(2*L2)) + atan2d(z, sqrt(x^2+y^2)) )) * (-1);
    theta3 = -2 * acosd(L/(2*L2));
    theta4 = -1* (pen_angle - abs(theta2) - abs(theta3));
    
    % Bound Checking
    if theta1<theta1_min || theta2<theta2_min || theta3<theta3_min || theta4<theta4_min || theta1>theta1_max || theta2>theta2_max || theta3>theta3_max || theta4>theta4_max
        terminate();
        error("At least one calculated motor angle out of bounds. Motors terminated.");
    end

    theta1 = theta1 + 136.84;
    theta2 = theta2 + 178.06;
    theta3 = theta3 + 159.87;
    theta4 = theta4 + 95.01;

    thetas = [theta1, theta2, theta3, theta4];
end

function [nums, x_new, y_new, z_new] = MoveLinear(x1, y1, z1, x2, y2, z2, L2, L4, pen_angle)
    
    dist = sqrt((x2-x1)^2+(y2-y1)^2+(z2-z1)^2);
    steps = ceil(dist)*1;
    x_spacing = (x2-x1)/steps;
    y_spacing = (y2-y1)/steps;
    z_spacing = (z2-z1)/steps;
    
    thetas = IK(x1, y1, z1, L2, L4, pen_angle);
    for i = 1:steps
        thetas_new = IK(x1+x_spacing*i, y1+y_spacing*i, z1+z_spacing*i, L2, L4, pen_angle);
        thetas = [thetas; thetas_new];
    end
    thetas
    nums = ThetaToNums(thetas);
    x_new = x2;
    y_new = y2;
    z_new = z2;
end

function SendMotorCommands(nums, port_num, PROTOCOL_VERSION, MX28_GOAL_POSITION)
    
    for i = 1:height(nums)
        for j = 1:size(nums, 2)
            write4ByteTxRx(port_num, PROTOCOL_VERSION, j, MX28_GOAL_POSITION, typecast(int32(nums(i,j)), 'uint32'));
        end
    end
    
    % write4ByteTxRx(port_num, PROTOCOL_VERSION, i, MX28_GOAL_POSITION, typecast(int32(theta(i)), 'uint32'));
end

function nums = ThetaToNums(thetas)
    nums = thetas / 360 * 4096;
end

function thetas = NumsToTheta(nums)
    thetas = nums * 360 / 4096;
end

%//////////////////////////////////////////////////////////////////////////////////////////////////
% Calculate T Matrix - units: degrees and mm
%//////////////////////////////////////////////////////////////////////////////////////////////////
function T = TF(alpha,a,d,theta)
T = [cosd(theta)                 -sind(theta)            0           a
     sind(theta)*cosd(alpha) cosd(theta)*cosd(alpha) -sind(alpha) -sind(alpha)*d
     sind(theta)*sind(alpha) cosd(theta)*sind(alpha)  cosd(alpha)  cosd(alpha)*d
     0 0 0 1];
end