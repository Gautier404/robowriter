import numpy as np
from constants import *
from animate_arm import animate_arm
from tqdm import tqdm

def generate_link_angles(pen_position: np.array):
    """
    Outputs an array of link angles of the robot given a target pen tip position.
    
    parameters:
        pen_position: a 1D array of the x, y, z coordinates of the pen tip in mm 
            in the base coordinate frame.
    """
    x, y, z = pen_position
    
    # Calculate theta1
    theta1 = np.degrees(np.arctan2(y, x))

    # If theta1 goes out of bounds clip it at the limit
    if theta1 > THETA_1_MAX:
        theta1 = THETA_1_MAX
    elif theta1 < THETA_1_MIN:
        theta1 = THETA_1_MIN

    # determine location of x5, y5, z5
    # These calculations assume the pen is normal to a flat surface on the same plane as the base of the robot
    x5 = x
    y5 = y
    z5 = z + L5

    # determine location of x4, y4, z4
    x4 = x5 + np.cos(np.radians(theta1))*np.sin(np.radians(-THETA_5))*L4
    y4 = y5 + np.sin(np.radians(theta1))*np.sin(np.radians(-THETA_5))*L4
    z4 = z5 + np.cos(np.radians(-THETA_5))*L4


    # Calculate theta 3
    # This calculation is derived geometrically from the 3R 3D robot arm inverse kinematic example in the textbook
    r2 = np.sqrt(x4**2 + y4**2 + (z4 - L0)**2)

    # check to see if our point is too far away for the robot to reach TODO: make this acurate
    if r2 >= L2 + L3:
        raise ValueError("Target point is too far away for the robot to reach.")

    c3 = (r2**2 - L2**2 - L3**2) / (2 * L2 * L3)
    s3 = np.sqrt(1 - c3**2)
    theta3 = np.degrees(np.arctan2(s3, c3)) #this assumes that the triangle formed by link 2 and 3 has an obtuse side pointed up

    # make sure theta3 is within the limits of the robot
    if theta3 < THETA_3_MIN:
        theta3 = THETA_3_MIN
    elif theta3 > THETA_3_MAX:
        theta3 = THETA_3_MAX

    # Calculate theta 2
    alpha = np.degrees(np.arctan2(z4 - L0, np.sqrt(x4**2 + y4**2)))
    cbeta = (L2**2 + r2**2 - L3**2) / (2 * L2 * r2)
    sbeta = np.sqrt(1 - cbeta**2)
    beta = np.degrees(np.arctan2(sbeta, cbeta)) #this assumes that the triangle formed by link 2 and 3 has an obtuse side pointed up
    theta2 = 90 - alpha - beta

    # make sure theta2 is within the limits of the robot
    if theta2 < THETA_2_MIN:
        theta2 = THETA_2_MIN
    elif theta2 > THETA_2_MAX:
        theta2 = THETA_2_MAX

    # Calculate theta 4
    theta4 = 180 - (theta2 + theta3 + THETA_5)

    # make sure theta4 is within the limits of the robot
    if theta4 < THETA_4_MIN:
        theta4 = THETA_4_MIN
    elif theta4 > THETA_4_MAX:
        theta4 = THETA_4_MAX

    return [theta1, theta2, theta3, theta4]

def generate_angular_toolpath(cartesian_toolpath: np.array):
    """
    Outputs an array of link angles of the robot given a target pen tip position.
    
    parameters:
        cartesian_toolpath: a 2D array of the x, y, z coordinates of the pen tip in mm 
            in the base coordinate frame.
    """
    angular_toolpath = np.zeros((len(cartesian_toolpath), 4))
    for i, position in enumerate(cartesian_toolpath):

        angular_toolpath[i] = generate_link_angles(position)
    return angular_toolpath

if __name__ == "__main__":
    home_cartesian = [115, 0, 54]
    home_degrees = generate_link_angles(home_cartesian)
    print(home_degrees)

    time_steps = 40
    toolpath = np.array([
        np.append(np.linspace(100, 100, time_steps), np.linspace(100, 200, time_steps)),
        np.append(np.linspace(0, 200, time_steps), np.linspace(200, 200, time_steps)),
        np.append(np.linspace(0, 0, time_steps), np.linspace(0, 0, time_steps))
    ])
    toolpath = toolpath.T
    angular_toolpath = generate_angular_toolpath(toolpath)
    animate_arm(angular_toolpath)

    