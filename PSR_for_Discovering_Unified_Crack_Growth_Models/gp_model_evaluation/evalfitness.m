function gp = evalfitness(gp,gen_count)
%EVALFITNESS Calls the user specified fitness function.
%
%   GP = EVALFITNESS(GP) evaluates the the fitnesses of individuals stored
%   in the GP structure and updates various other fields of GP accordingly.
%
%   Copyright (c) 2009-2015 Dominic Searson
%   Copyright (c) 2023-2025 Chaoyang Wang
%   GPTIPS 2
%
%   See also TREE2EVALSTR, EVALFITNESS_PAR

%check parallel mode.
if gp.runcontrol.parallel.enable && gp.runcontrol.parallel.ok
    gp.fitness.gen_count_now=gen_count;
    gp = evalfitness_par(gp,gen_count);
    return;
    
    %regular version
else
    
    for i = 1:gp.runcontrol.pop_size
        
        gp.state.current_individual = i;
        
        %retrieve values if cached
        if gp.runcontrol.usecache && gp.fitness.cache.isKey(i)
            cache = gp.fitness.cache(i);
            gp.fitness.complexity(i,1) = cache.complexity;
            gp.fitness.values(i,1) = cache.value;
            gp.fitness.returnvalues{i,1} = cache.returnvalues;
            
        else
            %preprocess cell array of string expressions into a form that
            %Matlab can evaluate
            evalstr = tree2evalstr(gp.pop{i},gp);
            
            %store complexity of individual (either number of nodes or tree
            %expressional complexity)
            if gp.fitness.complexityMeasure
                gp.fitness.complexity(i,1) = getcomplexity(gp.pop{i});
            else
                gp.fitness.complexity(i,1) = getnumnodes(gp.pop{i});
            end
            
            [fitness,gp] = feval(gp.fitness.fitfun,evalstr,gp);
            gp.fitness.values_alldata{i,1}=fitness;
            gp.fitness.values(i) = sum( fitness)/size(fitness,2);
            %gp.fitness.values(i) = fitness;
            
        end
    end
end