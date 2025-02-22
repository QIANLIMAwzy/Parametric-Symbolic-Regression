function gp = updatestats(gp)
%UPDATESTATS Update run statistics.
%
%   GP = UPDATESTATS(GP) updates the stats of the GP struct.
%
%   Copyright (c) 2009-2015 Dominic Searson
%   Copyright (c) 2023-2025 Chaoyang Wang
%   GPTIPS 2
%
%   See also DISPLAYSTATS, GPINIT, GPFINALISE

%check for NaN fitness values
nanInd = isnan(gp.fitness.values);

%write best fitness of current generation to gp struct
if gp.fitness.minimisation
    
    gp.fitness.values(nanInd) = Inf;
    bestTrainFitness = min(gp.fitness.values);
    
else %maximisation of fitness function
    
    %replace Inf and NaN with -Inf
    infInd = isinf(gp.fitness.values);
    gp.fitness.values(infInd) = -Inf;
    gp.fitness.values(nanInd) = -Inf;
    bestTrainFitness = max(gp.fitness.values);
    
end

%There may be more than one individual with best fitness. If so designate
%as "best" the one with the lowest complexity/node count. If there is more
%than one with the same complexity then just pick the first one
%(effectively a random selection). This doesn't affect the GP run, it only
%affects the reporting of which individual is currently considered "best".
bestTrainInds = find(gp.fitness.values == bestTrainFitness);

nodes = gp.fitness.complexity(bestTrainInds);

[~,ind] = min(nodes);
bestTrainInd = bestTrainInds(ind);

%store best of current population (training)
gp.state.best.fitness = bestTrainFitness;
gp.state.best.individual = gp.pop{bestTrainInd};
gp.state.best.returnvalues = gp.fitness.returnvalues{bestTrainInd};
gp.state.best.complexity = getcomplexity(gp.state.best.individual);
gp.state.best.nodecount = getnumnodes(gp.state.best.individual);


if gp.fitness.auto_renew_limit
    if gp.fitness.gen_count_now<=gp.runcontrol.stage1                                 
        if gp.state.best.fitness<1e-10
            gp.fitness.loss_MSE_limit=1e-10;
        else
            gp.fitness.loss_MSE_limit=gp.state.best.fitness*gp.fitness.loss_MSE_limit_index;              
        end
    end
end

if gp.fitness.auto_renew_limit
    if (gp.fitness.gen_count_now>gp.runcontrol.stage1)&& (gp.fitness.gen_count_now<=gp.runcontrol.stage2)                     
        if gp.state.best.fitness<1e-10
            gp.fitness.loss_VAR_limit=1e-10;                                       
        else
            gp.fitness.loss_VAR_limit=gp.state.best.fitness*gp.fitness.loss_VAR_limit_index;                
        end
    end
end

if    gp.state.best.complexity<5
    gp.state.best.complexity
    warning('gp.state.best.complexity<5');
    %pause;
end

if    gp.state.best.fitness>1
    gp.state.best.fitness
    warning('gp.state.best.fitness>1');
    %pause;
end


gp.state.best.individual
gp.state.best.returnvalues{1,5}
gp.state.best.returnvalues{1,4}

gp.results.history.bestfitness(gp.state.count,1) = bestTrainFitness;
gp.state.best.index = bestTrainInd;

%calc. mean and std. dev. fitness (exc. inf values)
notinfInd = ~isinf(gp.fitness.values);
gp.state.meanfitness = mean(gp.fitness.values(notinfInd));
gp.state.std_devfitness = std(gp.fitness.values(notinfInd));
gp.results.history.meanfitness(gp.state.count,1) = gp.state.meanfitness;
gp.results.history.std_devfitness(gp.state.count,1) = gp.state.std_devfitness;

if  1
%update best of run so far on training data
%if gp.state.count == 1 %if first gen then "best of run" is best of current gen
    
    gp.results.best.fitness = gp.state.best.fitness;
    gp.results.best.individual = gp.state.best.individual;
    gp.results.best.returnvalues = gp.state.best.returnvalues;
    gp.results.best.complexity = gp.state.best.complexity;
    gp.results.best.nodecount = gp.state.best.nodecount;
    gp.results.best.foundatgen = 0;
    gp.results.best.eval_individual = tree2evalstr(gp.state.best.individual,gp);
    
    %update run "best" fitness if current gen best fitness is better (or
    %the same but less complex)
else
    
    updateTrainBest = false;
    
    %update 'best' depending on chosen measure of complexity
    if gp.fitness.complexityMeasure
        stateComp = gp.state.best.complexity;
        bestComp =  gp.results.best.complexity;
    else
        stateComp = gp.state.best.nodecount;
        bestComp =  gp.results.best.nodecount;
    end
    
    %if minimising fitness function
    if gp.fitness.minimisation
        
        if (gp.state.best.fitness < gp.results.best.fitness) ...
                || ( (stateComp < bestComp) && (gp.state.best.fitness == gp.results.best.fitness) )
            updateTrainBest = true;
        end
        
        %if maximising fitness function
    else
        
        if (gp.state.best.fitness > gp.results.best.fitness) ...
                || ( (stateComp < bestComp) && (gp.state.best.fitness == gp.results.best.fitness) )
            updateTrainBest = true;
        end
    end
    
    if updateTrainBest
        gp.results.best.fitness = gp.state.best.fitness;
        gp.results.best.individual = gp.state.best.individual;
        gp.results.best.returnvalues = gp.state.best.returnvalues;
        gp.results.best.complexity = gp.state.best.complexity;
        gp.results.best.nodecount = gp.state.best.nodecount;
        gp.results.best.foundatgen = gp.state.count - 1;
        gp.results.best.eval_individual = tree2evalstr(gp.state.best.individual,gp);
    end
    
end
