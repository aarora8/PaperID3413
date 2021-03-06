% performing simulations for experiments
clear; clc;
%[6,9,12,14,15,18,21]
for S = [4,6,9,12,15]
    S
    load('../simulation_data_512.mat')
    Num_datapoints = 7200;
    m_1 = -1/4096;
    N = 7000; % number of training data points
    N_test = 200;
    Y_mat = zeros(n,N);
    X_mat = zeros(h,N);
    Y_test = zeros(n,N_test);
    X_test = zeros(h,N_test);
    var_x_star = 1/(256);
    for i = 1:Num_datapoints  
        x = zeros(h,1);
        x(1:S) = normrnd(m_1,var_x_star,[S 1]);
        if(i<=7000)
            y = A_star*x;
            Y_mat(:,i) = y;
            X_mat(:,i) = x;
        end
        if(i>7000)
            y = A_star*x;
            Y_test(:,i-7000) = y;
            X_test(:,i-7000) = x;
        end
    end
    % system parameters
    h = size(X_mat,1) % hidden layer size, sparse code dimension, 256

    eta = 0.03 % learning rate
    W = W_initial;
    W_T = W_T_initial;
    num_iter = 60 % number of iterations to run the simulation
    % WAstar_diff stores columnwise difference between A_star and 
    % weight matrix at every iteration
    WAstar_diff_per_iter = zeros(size(X_mat,1),num_iter+1);
    % it will store gradient of Weight matrix
    g_mat = zeros(size(X_mat,1),size(Y_mat,1)); % gradient matrix

    % defining lambda 1 and labda 2, regularization parameters
    delta = 0.95; % used in loss function
    epsilon_i = 1/2*abs(m_1)*S*(delta+mu_by_root_n); % epsilon in theorm 3.1
    C = (1 - delta)^2;  % remark, after theorm 3.2
    q_i = S/h; % sparsity probability  
    term_l1_1 = C*h*S; % 3.2 proposed gradient, term for lambda 1
    term_l1_2 = h*q_i*(1 - delta)^2; % 3.2 proposed gradient, term for lambda 1
    lambda_1 = term_l1_1 + term_l1_2;% 3.2 proposed gradient, lambda 1
    lambda_2 = -1; % 3.2 proposed gradient, lambda 1

    % difference between the y value obtained from 
    % randomly initialised  weight matrix
    % and actual y value obtained from A and X
    Y_diff_norm_per_iter = [];
    Y_diff_norm = 0;
    for i = 1:N_test
        Y_diff_initial = W_T*X_test(:,i) - A_star*X_test(:,i);
        Y_diff_norm = Y_diff_norm + norm(Y_diff_initial,2);
    end
    Y_diff_norm = (1/N_test)*Y_diff_norm;
    Y_diff_norm_per_iter = [Y_diff_norm_per_iter Y_diff_norm];

    iter=1;
    for i =1:size(X_mat,1)
        W1 = W_T(:,i) - A_star(:,i);
        colnorm=sqrt(sum(W1.^2,1));
        WAstar_diff_per_iter(i,iter) = colnorm;
    end

    gradient_norm_per_iter = [];
    % norm of gradient of each row, at every iteration
    gmat_val = [];
    for iter =1:num_iter 
        iter
        g_mat = zeros(size(X_mat,1),size(Y_mat,1)); % 256X100
        for i= 1:S
            final_term =zeros(size(Y_mat,1),1); % differentiation term of loss 1
            regularization_term_2= zeros(size(Y_mat,1),1);
            W_T = W';
            if(i<=S)
                for k=1:N
                    term_1 = (W_T(:,i)'*Y_mat(:,k) - epsilon_i).*eye(size(Y_mat,1));
                    term_2 = (W_T(:,i)*Y_mat(:,k)');
                    term12 = term_1 + term_2;
                    term_jh = zeros(size(Y_mat,1),1);
                    for j=1:h
                        term_wTY = W_T(:,j)'*Y_mat(:,k) - epsilon_i;
                        term_jh = term_jh+ (term_wTY)* W_T(:,j);
                    end
                    term_CHY = C*h*Y_mat(:,k);
                    termjh_chy = term_jh - term_CHY;
                    term_prod_ab = term12 * termjh_chy;
                    final_term = final_term + term_prod_ab;
                end
                final_term = (1/N)*final_term; % taking expectation of the first loss term
            end % end if 
            regularization_term_1  = lambda_1*W_T(:,i);% first regularization term
            % summing the regularization term 2 over all data points 
            % since it contains a y term 
            for k=1:N
                W_tilda = zeros(size(X_mat,1),size(Y_mat,1)); 
                W_tilda(1:4,:) = W(1:4,:);
                term_wy = norm(W_tilda*Y_mat(:,k),2)^2;
                term_aa = lambda_2 *term_wy*W_T(:,i);
                fnorm = 0;
                for i1 =1:4
                    w1 = W_tilda(i1,:);
                    rownorm=sum(w1'.^2,1);  
                    fnorm = fnorm+ rownorm;
                end
                term_ab = lambda_2*fnorm*W_T(:,i)'*Y_mat(:,k)*Y_mat(:,k);
                regularization_term_2 = regularization_term_2+term_aa+ term_ab;
            end
            regularization_term_2 = (1/N)*regularization_term_2; % second regularization term
            % gradient of ith column of w transpose
            g_i = final_term + regularization_term_1 + regularization_term_2; 
            g_mat(i,:) = g_i'; % taking transpose to get gradient of ith row of W
            colnorm=sqrt(sum(g_i.^2,1));
            if(i == 1)
                 gradient_norm_per_iter = [gradient_norm_per_iter colnorm];
            end

            % break if gradient has become 100 times smaller
            if(gradient_norm_per_iter(1,iter)/gradient_norm_per_iter(1,1)<0.01) 
                break;
            end
        end % end for ifrom 1 to s

         % break if gradient has become 100 times smaller
         if(gradient_norm_per_iter(1,iter)/gradient_norm_per_iter(1,1)<0.01)
                 break;
         end

        % norm of gradient of each row, at every iteration
        gmat_val = [gmat_val sqrt(diag(g_mat*g_mat'))]; 
        W = W-eta*g_mat; % updating W matrix
        W_T = W'; % reassigning W transpose
        for i =1:size(X_mat,1)
            W1 = W_T(:,i) - A_star(:,i);
            colnorm=sqrt(sum(W1.^2,1));
            WAstar_diff_per_iter(i,iter+1) = colnorm;
        end

         Y_diff_norm = 0;
         for i2 = 1:N_test
             Y_diff_initial = W_T*X_test(:,i2) - A_star*X_test(:,i2);
             Y_diff_norm = Y_diff_norm + norm(Y_diff_initial,2);
         end
         Y_diff_norm = (1/N_test)*Y_diff_norm;
         Y_diff_norm_per_iter = [Y_diff_norm_per_iter Y_diff_norm];

    end % end num iter 

    W_T_final_bn = W';
    % normalizing W
    W_T = W';
    for i =1:size(X_mat,1)
        colnorm=sqrt(sum(W_T(:,i).^2,1));
        W_T(:,i) = W_T(:,i)./colnorm;
    end
    W = W_T';

    W_T_final = W';
    Y_diff_norm = 0;
    for i = 1:N_test
        Y_diff_initial = W_T_final*X_test(:,i) - A_star*X_test(:,i);
        Y_diff_norm = Y_diff_norm + norm(Y_diff_initial,2);
    end
    Y_diff_norm = (1/N_test)*Y_diff_norm;
    Y_diff_norm_per_iter = [Y_diff_norm_per_iter Y_diff_norm];

    % removing unnecessary variables before storing
    clear colnorm final_term fnorm g_i i i1 iter j k N num_iter q_i regularization_term_1   
    clear regularization_term_2 rownorm term12 term_1 term_2 term_aa term_ab term_CHY
    clear term_jh term_l1_1 term_l1_2 term_prod_ab term_wTY term_wy termjh_chy var_weight
    clear w1 W1 W_tilda C delta epsilon_i g_mat lambda1 lambda2 
    clear n mu_by_root_n A_star W_initial W_T_initial ball_distance x y
    clear W W_T Y_diff_initial Y_diff_norm var_x_star Num_datapoints N_test m_1 lambda_1 lambda_2 i2 gmat_val

    % most important variables are Y_diff_per_iter WAstar_diff_iter gradient_val_per_iter 
    result = strcat('result_sparsity',int2str(S),'.mat');
    save (result,'eta','S', 'gradient_norm_per_iter','W_T_final','W_T_final_bn','WAstar_diff_per_iter','X_mat','X_test','Y_diff_norm_per_iter','Y_mat','Y_test'); 
end 
