%% CORDIC MATLAB Model - Golden Reference Implementation
% This model implements the CORDIC algorithm using fixed-point arithmetic
% to match the Verilog implementation exactly

function matlab_model()
    clc; clear; close all;
    
    %% Parameters (matching Verilog implementation)
    WIDTH = 16;           % Data width for coordinates
    ITERATIONS = 15;      % Number of CORDIC iterations
    ANGLE_WIDTH = 32;     % Angle width in bits
    
    %% Fixed-point scaling factors
    COORD_SCALE = 2^(WIDTH-2);     % Coordinate scaling factor
    ANGLE_SCALE = 2^(ANGLE_WIDTH-3); % Angle scaling factor
    
    %% CORDIC constants
    % CORDIC gain compensation factor (≈ 0.6072529350088812561694)
    CORDIC_GAIN_REAL = 0.6072529350088812561694;
    CORDIC_GAIN_FIXED = round(CORDIC_GAIN_REAL * COORD_SCALE);
    
    %% Arctangent lookup table (matching Verilog)
    % atan(2^-i) values scaled for fixed-point representation
    ATAN_TABLE = [
        hex2dec('20000000');  % atan(2^0)
        hex2dec('12E4051E');  % atan(2^-1)
        hex2dec('09FB385B');  % atan(2^-2)
        hex2dec('051111D4');  % atan(2^-3)
        hex2dec('028B0D43');  % atan(2^-4)
        hex2dec('0145D7E1');  % atan(2^-5)
        hex2dec('00A2F61E');  % atan(2^-6)
        hex2dec('00517C55');  % atan(2^-7)
        hex2dec('0028BE53');  % atan(2^-8)
        hex2dec('00145F2F');  % atan(2^-9)
        hex2dec('000A2F98');  % atan(2^-10)
        hex2dec('000517CC');  % atan(2^-11)
        hex2dec('00028BE6');  % atan(2^-12)
        hex2dec('000145F3');  % atan(2^-13)
        hex2dec('0000A2FA')   % atan(2^-14)
    ];
    
    %% Test angles (in degrees)
    test_angles_deg = [0, 30, 45, 60, 90, 120, 135, 150, 180, 210, 225, 240, 270, 300, 315, 330, 360, 450, -90, -180];
    
    %% Run tests and compare with MATLAB built-in functions
    fprintf('=== CORDIC MATLAB Model Verification ===\n');
    fprintf('Parameters: WIDTH=%d, ITERATIONS=%d, ANGLE_WIDTH=%d\n', WIDTH, ITERATIONS, ANGLE_WIDTH);
    fprintf('CORDIC Gain: %.10f (Fixed: %d)\n\n', CORDIC_GAIN_REAL, CORDIC_GAIN_FIXED);
    
    fprintf('%-10s %-10s %-10s %-10s %-10s %-10s %-10s\n', ...
            'Angle(°)', 'MATLAB_cos', 'CORDIC_cos', 'Cos_Error', 'MATLAB_sin', 'CORDIC_sin', 'Sin_Error');
    fprintf('%s\n', repmat('-', 1, 80));
    
    total_cos_error = 0;
    total_sin_error = 0;
    max_cos_error = 0;
    max_sin_error = 0;
    
    for i = 1:length(test_angles_deg)
        angle_deg = test_angles_deg(i);
        angle_rad = angle_deg * pi / 180;
        
        % MATLAB reference values
        matlab_cos = cos(angle_rad);
        matlab_sin = sin(angle_rad);
        
        % CORDIC calculation
        [cordic_cos, cordic_sin] = cordic_fixed_point(angle_rad, CORDIC_GAIN_FIXED, ...
                                                     ATAN_TABLE, ITERATIONS, COORD_SCALE, ANGLE_SCALE);
        
        % Calculate errors
        cos_error = abs(matlab_cos - cordic_cos);
        sin_error = abs(matlab_sin - cordic_sin);
        
        % Accumulate statistics
        total_cos_error = total_cos_error + cos_error;
        total_sin_error = total_sin_error + sin_error;
        max_cos_error = max(max_cos_error, cos_error);
        max_sin_error = max(max_sin_error, sin_error);
        
        % Print results
        fprintf('%-10.1f %-10.6f %-10.6f %-10.6f %-10.6f %-10.6f %-10.6f\n', ...
                angle_deg, matlab_cos, cordic_cos, cos_error, matlab_sin, cordic_sin, sin_error);
    end
    
    %% Statistics
    fprintf('\n=== Accuracy Statistics ===\n');
    fprintf('Average Cosine Error: %.8f\n', total_cos_error / length(test_angles_deg));
    fprintf('Average Sine Error:   %.8f\n', total_sin_error / length(test_angles_deg));
    fprintf('Maximum Cosine Error: %.8f\n', max_cos_error);
    fprintf('Maximum Sine Error:   %.8f\n', max_sin_error);
    
    % Calculate effective number of bits
    if max_cos_error > 0
        cos_bits = -log2(max_cos_error);
        fprintf('Cosine Accuracy: ~%.1f bits\n', cos_bits);
    end
    if max_sin_error > 0
        sin_bits = -log2(max_sin_error);
        fprintf('Sine Accuracy:   ~%.1f bits\n', sin_bits);
    end
    
    %% Generate plots
    figure('Position', [100, 100, 1200, 400]);
    
    % Plot 1: CORDIC vs MATLAB comparison
    subplot(1, 3, 1);
    angle_range = 0:1:360;
    matlab_cos_vals = cos(angle_range * pi / 180);
    matlab_sin_vals = sin(angle_range * pi / 180);
    
    cordic_cos_vals = zeros(size(angle_range));
    cordic_sin_vals = zeros(size(angle_range));
    
    for i = 1:length(angle_range)
        [cordic_cos_vals(i), cordic_sin_vals(i)] = cordic_fixed_point(angle_range(i) * pi / 180, ...
                                                                     CORDIC_GAIN_FIXED, ATAN_TABLE, ITERATIONS, COORD_SCALE, ANGLE_SCALE);
    end
    
    plot(angle_range, matlab_cos_vals, 'b-', 'LineWidth', 1.5, 'DisplayName', 'MATLAB cos');
    hold on;
    plot(angle_range, cordic_cos_vals, 'r--', 'LineWidth', 1, 'DisplayName', 'CORDIC cos');
    plot(angle_range, matlab_sin_vals, 'g-', 'LineWidth', 1.5, 'DisplayName', 'MATLAB sin');
    plot(angle_range, cordic_sin_vals, 'm--', 'LineWidth', 1, 'DisplayName', 'CORDIC sin');
    xlabel('Angle (degrees)');
    ylabel('Value');
    title('CORDIC vs MATLAB Comparison');
    legend('Location', 'best');
    grid on;
    
    % Plot 2: Error analysis
    subplot(1, 3, 2);
    cos_errors = abs(matlab_cos_vals - cordic_cos_vals);
    sin_errors = abs(matlab_sin_vals - cordic_sin_vals);
    
    semilogy(angle_range, cos_errors, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Cosine Error');
    hold on;
    semilogy(angle_range, sin_errors, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Sine Error');
    xlabel('Angle (degrees)');
    ylabel('Absolute Error');
    title('CORDIC Error Analysis');
    legend('Location', 'best');
    grid on;
    
    % Plot 3: CORDIC convergence
    subplot(1, 3, 3);
    test_angle = 60 * pi / 180; % Test with 60 degrees
    [~, ~, convergence_data] = cordic_fixed_point_debug(test_angle, CORDIC_GAIN_FIXED, ...
                                                       ATAN_TABLE, ITERATIONS, COORD_SCALE, ANGLE_SCALE);
    
    plot(0:ITERATIONS, convergence_data.x_vals, 'b-o', 'LineWidth', 1.5, 'DisplayName', 'X (cos)');
    hold on;
    plot(0:ITERATIONS, convergence_data.y_vals, 'r-o', 'LineWidth', 1.5, 'DisplayName', 'Y (sin)');
    plot(0:ITERATIONS, convergence_data.z_vals, 'g-o', 'LineWidth', 1.5, 'DisplayName', 'Z (angle)');
    xlabel('Iteration');
    ylabel('Value');
    title(sprintf('CORDIC Convergence (%.0f°)', test_angle * 180 / pi));
    legend('Location', 'best');
    grid on;
    
    % Save the plot
    saveas(gcf, 'cordic_analysis.png');
    
    fprintf('\nPlots saved as cordic_analysis.png\n');
    fprintf('MATLAB model verification complete!\n');
end

%% CORDIC Fixed-Point Implementation
function [cos_out, sin_out] = cordic_fixed_point(angle_rad, cordic_gain, atan_table, iterations, coord_scale, angle_scale)
    % Convert to fixed-point
    angle_fixed = round(angle_rad * angle_scale);
    
    % Quadrant correction
    [normalized_angle, x_sign, y_sign] = quadrant_correction(angle_fixed, angle_scale);
    
    % Initialize CORDIC variables
    x = cordic_gain;
    y = 0;
    z = normalized_angle;
    
    % CORDIC iterations
    for i = 1:iterations
        if z >= 0
            % Clockwise rotation
            x_new = x - arithmetic_right_shift(y, i-1);
            y_new = y + arithmetic_right_shift(x, i-1);
            z_new = z - atan_table(i);
        else
            % Counter-clockwise rotation
            x_new = x + arithmetic_right_shift(y, i-1);
            y_new = y - arithmetic_right_shift(x, i-1);
            z_new = z + atan_table(i);
        end
        
        x = x_new;
        y = y_new;
        z = z_new;
    end
    
    % Apply quadrant correction and convert to floating-point
    if x_sign
        x = -x;
    end
    if y_sign
        y = -y;
    end
    
    cos_out = double(x) / coord_scale;
    sin_out = double(y) / coord_scale;
end

%% CORDIC with debug information
function [cos_out, sin_out, debug_data] = cordic_fixed_point_debug(angle_rad, cordic_gain, atan_table, iterations, coord_scale, angle_scale)
    angle_fixed = round(angle_rad * angle_scale);
    [normalized_angle, x_sign, y_sign] = quadrant_correction(angle_fixed, angle_scale);
    
    x = cordic_gain;
    y = 0;
    z = normalized_angle;
    
    % Store convergence data
    debug_data.x_vals = zeros(1, iterations + 1);
    debug_data.y_vals = zeros(1, iterations + 1);
    debug_data.z_vals = zeros(1, iterations + 1);
    
    debug_data.x_vals(1) = double(x) / coord_scale;
    debug_data.y_vals(1) = double(y) / coord_scale;
    debug_data.z_vals(1) = double(z) / angle_scale;
    
    for i = 1:iterations
        if z >= 0
            x_new = x - arithmetic_right_shift(y, i-1);
            y_new = y + arithmetic_right_shift(x, i-1);
            z_new = z - atan_table(i);
        else
            x_new = x + arithmetic_right_shift(y, i-1);
            y_new = y - arithmetic_right_shift(x, i-1);
            z_new = z + atan_table(i);
        end
        
        x = x_new;
        y = y_new;
        z = z_new;
        
        debug_data.x_vals(i+1) = double(x) / coord_scale;
        debug_data.y_vals(i+1) = double(y) / coord_scale;
        debug_data.z_vals(i+1) = double(z) / angle_scale;
    end
    
    if x_sign, x = -x; end
    if y_sign, y = -y; end
    
    cos_out = double(x) / coord_scale;
    sin_out = double(y) / coord_scale;
end

%% Quadrant correction function
function [normalized_angle, x_sign, y_sign] = quadrant_correction(angle_fixed, angle_scale)
    PI = round(pi * angle_scale);
    PI_2 = round(pi/2 * angle_scale);
    TWO_PI = round(2*pi * angle_scale);
    
    normalized_angle = angle_fixed;
    x_sign = false;
    y_sign = false;
    
    % Normalize to [-2π, 2π]
    while normalized_angle > TWO_PI
        normalized_angle = normalized_angle - TWO_PI;
    end
    while normalized_angle < -TWO_PI
        normalized_angle = normalized_angle + TWO_PI;
    end
    
    % Quadrant correction
    if normalized_angle > PI_2 && normalized_angle <= PI
        % Second quadrant
        normalized_angle = PI - normalized_angle;
        x_sign = true;
    elseif normalized_angle > PI && normalized_angle <= (3*PI_2)
        % Third quadrant
        normalized_angle = normalized_angle - PI;
        x_sign = true;
        y_sign = true;
    elseif normalized_angle > (3*PI_2)
        % Fourth quadrant
        normalized_angle = TWO_PI - normalized_angle;
        y_sign = true;
    elseif normalized_angle < -PI_2
        if normalized_angle >= -PI
            % Third quadrant (negative)
            normalized_angle = -PI - normalized_angle;
            x_sign = true;
            y_sign = true;
        else
            % Second quadrant (negative)
            normalized_angle = normalized_angle + PI;
            x_sign = true;
        end
    end
end

%% Arithmetic right shift (sign-extending)
function result = arithmetic_right_shift(value, shift_amount)
    if value >= 0
        result = floor(value / (2^shift_amount));
    else
        result = -floor(abs(value) / (2^shift_amount));
    end
end