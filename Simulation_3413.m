clear
clc
 
h = 256;
S = 4;
n = 100;
m_1 = -1/4096;

A_star = randn(n,h);
A_star = orth(A_star')';

for i =1:h
    colnorm=sqrt(sum(A_star(:,i).^2,1));
    A_star(:,i) = A_star(:,i)./colnorm;
end

coherence_mat = A_star'*A_star;
mu_max= 0;
for i = 1:n
    for j = 1:h
        if(i~=j)
            if(abs(coherence_mat(i,j))>mu_max)
                mu_max = abs(coherence_mat(i,j));
            end
        end
    end
end
Num_datapoints = 7200;
 
Y_mat = zeros(n,7000);
X_mat = zeros(h,7000);
Y_test = zeros(n,200);
X_test = zeros(h,200);
var_x_star = 1/(h*log(n));
for i = 1:Num_datapoints  
    x = zeros(h,1);
    x(1:S) = normrnd(- 1/4096,var_x_star,[S 1]);
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
mu_by_root_n = mu_max;

clear x y i j mu_max var_x_star Num_datapoints coherence_mat colnorm S n h 

% system parameters
N = size(Y_mat,2); % number of data points, 7000
h = size(X_mat,1); % hidden layer size, sparse code dimension, 256
eta = 0.05; % learning rate
S = 4; % support size   

% defining lambda 1 and labda 2, regularization parameters
delta = 0.95; % used in loss function
epsilon_i = 1/2*abs(m_1)*S*(delta+mu_by_root_n); % epsilon in theorm 3.1
C = (1 - delta)^2;  % remark, after theorm 3.2

q_i = S/h; % sparsity probability  
term_l1_1 = C*h*S; % 3.2 proposed gradient, term for lambda 1
term_l1_2 = h*q_i*(1 - delta)^2; % 3.2 proposed gradient, term for lambda 1
lambda_1 = term_l1_1 + term_l1_2;% 3.2 proposed gradient, lambda 1
lambda_2 = -1; % 3.2 proposed gradient, lambda 1

% it will store gradient of Weight matrix
g_mat = zeros(size(X_mat,1),size(Y_mat,1)); % gradient matrix
 

% creating a randomly initialised  weight matrix
% this weight matrix will be in the columnwise ball distance of A_star
W = zeros(size(X_mat,1),size(Y_mat,1)); % weight matrix
var_weight = 1; 
W_T = W';
ball_distance = 2;
for i =1:size(X_mat,1)
    W1 = normrnd(0,var_weight,[size(Y_mat,1),1]);
    colnorm=sqrt(sum(W1.^2,1));
    W1 = (ball_distance)*W1./colnorm;
    W_T(:,i) = A_star(:,i) - W1;
end
W = W_T';

% difference between the y value obtained from 
% randomly initialised  weight matrix
% and actual y value obtained from A and X
Y_diff_initial = W'*X_test(:,1) - A_star*X_test(:,1);
Y_diff_initial_norm = norm(Y_diff_initial,2);

% X_mat is defined in data generation
% WAstar_diff_initial is columnwise difference between A_star and 
% randomly initialised  weight matrix
WAstar_diff_initial = zeros(size(X_mat,1),1);
for i =1:size(X_mat,1)
    W1 = W_T(:,i) - A_star(:,i);
    colnorm=sqrt(sum(W1.^2,1));
    WAstar_diff_initial(i,1) = colnorm;
end

gradient_val = [];
% norm of gradient of each row, at every iteration
gmat_val = [];
num_iter = 5; % number of iterations to run the simulation
% WAstar_diff stores columnwise difference between A_star and 
% weight matrix at every iteration
WAstar_diff = zeros(size(X_mat,1),num_iter);
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
             gradient_val = [gradient_val colnorm];
        end
        % break if gradient has become 100 times smaller
        if(gradient_val(1,iter)/gradient_val(1,1)<0.01) 
            break;
        end
    end % end for ifrom 1 to s
    
     % break if gradient has become 100 times smaller
     if(gradient_val(1,iter)/gradient_val(1,1)<0.01)
             break;
     end

    % norm of gradient of each row, at every iteration
    gmat_val = [gmat_val sqrt(diag(g_mat*g_mat'))]; 
    W = W-eta*g_mat; % updating W matrix
    W_T = W'; % reassigning W transpose
    for i =1:size(X_mat,1)
        W1 = W_T(:,i) - A_star(:,i);
        colnorm=sqrt(sum(W1.^2,1));
        WAstar_diff(i,iter) = colnorm;
   end
end % end num iter 

% difference between the y value obtained from 
% converged weight matrix before normalization
% and actual y value obtained from A and X
W_T_before_normlization = W';
Y_diff_final_before_normlization = W_T_before_normlization*X_test(:,1) - A_star*X_test(:,1);
Y_diff_final_bn_norm = norm(Y_diff_final_before_normlization,2);

% W_diff_fbn is columnwise difference between A_star and 
% converged weight matrix before normalization
W_diff_fbn = zeros(size(X_mat,1),1);
for i =1:size(X_mat,1)
    W1 = W_T_before_normlization(:,i) - A_star(:,i);
    colnorm=sqrt(sum(W1.^2,1));
    W_diff_fbn(i,1) = colnorm;
end

% difference between the y value obtained from 
% converged weight matrix
% and actual y value obtained from A and X
W_T = W';
for i =1:size(X_mat,1)
    colnorm=sqrt(sum(W_T(:,i).^2,1));
    W_T(:,i) = W_T(:,i)./colnorm;
end
W = W_T';
Y_diff_final = W'*X_test(:,1) - A_star*X_test(:,1);
Y_diff_final_norm = norm(Y_diff_final,2);