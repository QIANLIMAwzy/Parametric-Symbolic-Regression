function [exprSym,geneExprSym,fullLatexExpr,geneLatexExpr] = gppretty(gp,ID,knockout,separateBias,fastMode,useAlias)
%GPPRETTY Simplify and prettify a multigene symbolic regression model.
%
%   Simplifies single and multigene symbolic regression models created with
%   GPTIPS using the REGRESSMULTI_FITFUN fitness function (and variants
%   thereof with file name beginning 'REGRESSMULTI').
%
%   GPPRETTY(GP,ID) simplifies the model with numeric population identifier
%   ID in the GPTIPS datastructure GP.
%
%   GPPRETTY(GP,'best') simplifies the best model of the run (as evaluated
%   on the training data).
%
%   GPPRETTY(GP,'valbest') simplifies the model that performed best on the
%   validation data (if it exists).
%
%   GPPRETTY(GP,'testbest') simplifies the model that performed best on the
%   test data (if it exists).
%
%   GPPRETTY(GP,GPMODEL) prettifies the multigene regression model
%   structure GPMODEL (i.e. the struct created by the function
%   GPMODEL2STRUCT or by the function GENES2GPMODEL).
%
%   EXPRSYM = GPPRETTY(GP,'best') does the above and and returns the entire
%   simplified symbolic expression as an object of class SYM as EXPRSYM.
%
%   [EXPRSYM,GENEEXPRSYM] = GPPRETTY(GP,'best') also returns the individual
%   simplified gene expressions as a cell array of SYM objects GENEEXPRSYM.
%
%   Advanced:
%
%   GPPRETTY can also accept an optional third argument KNOCKOUT which
%   should be a boolean vector the with same number of entries as genes in
%   the individual to be simplified. This simplifies the individual with
%   the indicated genes removed ('knocked out').
%
%   E.g. GPPRETTY(GP,'best',[1 0 0 1]) knocks out the 1st and 4th genes
%   from the best model of the run, then simplifies it. Note that the gene
%   weights are recomputed from the training data when genes are knocked
%   out.
%
%   [EXPRSYM,GENEEXPRSYM,FULLLATEXEXPR] = GPPRETTY(GP,'best') also returns
%   FULLLATEXEXPR containing the simplified LaTeX representation of the
%   combined genes of the multigene equation. That is, the genes are
%   combined, then simplified.
%
%   [EXPRSYM,GENEEXPRSYM,FULLLATEXEXPR,GENELATEXEXPR = GPPRETTY(GP,'best')
%   returns a string GENELATEXEXPR containing the simplified LaTeX
%   representation of the separate genes of the multigene equation
%   formatted as a LaTeX equation array. The bias term is 'folded' in with
%   the first gene. The genes are simplified separately and are displayed
%   on different lines of the LaTex expression.
%
%   Remarks on precision and simplification:
%
%   In GPTIPS 2 symbolic expressions are now simplified directly using the
%   MuPAD engine's 'Simplify' method (instead of the MATLAB SIMPLE function
%   used in GPTIPS v1).
%
%   This is due to:
%
%   (a) ongoing problems with SIMPLE causing MATLAB to hang occasionally.
%
%   (b) the 'SIMPLE' method is now deprecated by MATLAB (R2014b).
%
%   GPPRETTY by default displays expressions with 4 digits of 'accuracy'.
%
%   You can also use the GPMODEL2SYM function to return the GPTIPS
%   expresssion as a SYM object. You can then use the Symbolic Math Toolbox
%   VPA function to control the display precision. E.g.
%
%   EQ = GPMODEL2SYM(GP,'best');
%   EQ_TWO_DIGITS = VPA(S,2)
%
%   In the previous version of GPTIPS, symbolic math objects were created
%   from GPTIPS expressions using a fixed precision method (i.e. 4 digits).
%   This could sometimes lead to undesirable numerical properties if using
%   the SYM form of the model directly.
%
%   In GPTIPS 2 this has been rectified, symbolic math objects are always
%   created and stored with 'full' precision but are displayed by GPPRETTY,
%   GPMODELREPORT, HTMLEQUATION, VPA etc. to a controlled number of
%   significant digits. See SYM/VPA for more information.
%
%   Remarks on LaTex:
%
%   The LaTeX equation represented by the string GENELATEXEXPR must be
%   copied and pasted into the correct context in an appropriate LaTeX
%   document, for example:
%
%   \documentclass{article}
%   \pagestyle{empty}
%   \begin{document}
%   \begin{eqnarray*}y&=& 6.565- 0.2017\,\tanh \left( {\it x_2} \right)  \left(  0.8519\,{\it x_3}-{\it x_1} \right)\\&-& 0.3174\,\tanh \left( - 0.923039\,{\it x_3}\, \left( {\it x_3}-{\it x_1} \right) -{\it x_2} \right)\end{eqnarray*}
%   \end{document}
%
%   In the above LaTeX code above the line beginning "\begin{eqnarray*}" is
%   the string GENELATEXEXPR that is generated by GPPRETTY. The rest you
%   must supply yourself.
%
%   Again, the equation represented by the string FULLLATEXEXPR must be
%   copied and pasted into the correct context in an appropriate LaTeX
%   document, for example:
%
%   \documentclass{article}
%   \pagestyle{empty}
%   \begin{document}
%   $
%   y= 7.255+ 0.2060\,{\it x_2}+ 0.2086\,{\it x_3}- 0.2086\,{\it x_1}- 0.2086\,\tanh \left( {\it x_1} \right)
%   $
%   \end{document}
%
%   Copyright (c) 2009-2015 Dominic Searson
%   Copyright (c) 2023-2025 Chaoyang Wang
%   GPTIPS 2
%
%   See also GPSIMPLIFY, GPMODEL2MFILE, GPMODEL2SYM, GPMODELREPORT,
%   GPMODEL2STRUCT, GPMODEL2FUNC, SYM/PRETTY, SYM/VPA, SYM/SIMPLIFY

if nargin < 2
    disp('Usage is GPPRETTY(GP,ID) where ID is the population identifer of the desired individual');
    disp('or GPPRETTY(GP,''BEST'') to use the best individual of the run ');
    disp('or GPPRETTY(GP,''VALBEST'') uses the individual from the run that performed best on the validation set (if one is defined). ');
    disp('or GPPRETTY(GP,''TESTBEST'') uses the individual from the run that performed best on the test set (if one is defined). ');
    return;
end

verReallyOld = verLessThan('matlab', '7.7.0');

%Set the max number of steps for each Mupad SIMPLIFY function call to
%take. The MuPAD default is 100. Edit this to to take more or less steps.
%This doesn't seem have any effect on old (<7.7) versions of MATLAB)
simplifySteps = 100;

if nargin < 3 || isempty(knockout)
    knockout = 0;
end

if nargin < 4 || isempty(separateBias)
    separateBias = false;
end

if nargin < 5 || isempty(fastMode)
    fastMode = false;
end

if nargin < 6 || isempty(useAlias)
    useAlias = true;
end

if isempty(knockout) || ~any(knockout)
    doknockout = false;
else
    doknockout = true;
end

if gp.info.toolbox.symbolic
    
    if isnumeric(ID)
        
        if ID > gp.runcontrol.pop_size || ID < 1
            error('Supplied population index is invalid.');
        end
        
        %if no return values
        if isempty(gp.fitness.returnvalues{ID})
            if gp.genes.multigene
                error('No gene weights were computed for this model. This is probably because one or more genes gave a non-finite output on the training data.');
            else %if single gene/regular GP (e.g. quartic poly) then set bias = 0 and weight = 1
                gp.fitness.returnvalues{ID}(1) = 0;
                gp.fitness.returnvalues{ID}(2) = 1;
            end
        end
        
        %knockout genes if required
        if doknockout
            treestrs_eval = kogene(gp.results.best.eval_individual, knockout);
            treestrs = kogene(gp.results.best.individual, knockout);
            gp.state.run_completed = false; %force fitness function into recomputing weights
            [~,gp,coeffs] = feval(gp.fitness.fitfun,treestrs_eval,gp);
            gp.fitness.returnvalues{ID} = coeffs;
            evalTree = gpreformat(gp,treestrs,useAlias);
        else
            evalTree = gpreformat(gp,gp.pop{ID},useAlias);
        end
        
        %construct full symbolic expression using gene weights and gene expressions
        
        if separateBias %bias is kept as a separate "gene"
            
            fullExpr = sym(gp.fitness.returnvalues{ID}(1));
            exprArray = cell(1, numel(evalTree)+1);
            exprArray{1} = gpsimplify(fullExpr,simplifySteps,verReallyOld,fastMode);
            
            for i=1:length(evalTree);
                geneExpr = gp.fitness.returnvalues{ID}(i+1)*sym(evalTree{i});
                fullExpr = fullExpr + geneExpr;
                exprArray{i+1} = gpsimplify(geneExpr,simplifySteps,verReallyOld,fastMode);
            end
            
        else %normal processing where bias is folded into first gene
            fullExpr = gp.fitness.returnvalues{ID}(1) + gp.fitness.returnvalues{ID}(2)*sym(evalTree{1});
            exprArray = cell(1, numel(evalTree));
            exprArray{1} = gpsimplify(fullExpr,simplifySteps,verReallyOld,fastMode);
            
            for i=2:length(evalTree);
                geneExpr = gp.fitness.returnvalues{ID}(i+1) * sym(evalTree{i});
                fullExpr = fullExpr + geneExpr;
                exprArray{i} = gpsimplify(geneExpr,simplifySteps,verReallyOld,fastMode);
            end
        end
        
    elseif ischar(ID) && strcmpi(ID,'best')
        
        if isempty(gp.results.best.returnvalues)
            gp.results.best.returnvalues(1) = 0;
            gp.results.best.returnvalues(2) = 1;
        end
        
        %knockout genes if required, this requires that coefficients are
        %recomputed on the training data
        if doknockout
            treestrs_eval = kogene(gp.results.best.eval_individual, knockout);
            treestrs = kogene(gp.results.best.individual, knockout);
            gp.state.run_completed = false; %trick fitness function into recomputing weights
            [~,gp,coeffs] = feval(gp.fitness.fitfun,treestrs_eval,gp);
            gp.results.best.returnvalues = coeffs;
            evalTree = gpreformat(gp,treestrs,useAlias);
        else
            evalTree = gpreformat(gp,gp.results.best.individual,useAlias);
        end
        
        if separateBias %bias is kept as a separate "gene"
            
            fullExpr = sym(gp.results.best.returnvalues(1));
            exprArray{1} = gpsimplify(fullExpr,simplifySteps,verReallyOld,fastMode);
            
            for i=1:length(evalTree);
                geneExpr = gp.results.best.returnvalues(i+1) * sym(evalTree{i});
                fullExpr = fullExpr + geneExpr;
                exprArray{i+1} = gpsimplify(geneExpr,simplifySteps,verReallyOld,fastMode);
            end
            
        else
            
            fullExpr = gp.results.best.returnvalues(1) + gp.results.best.returnvalues(2)*sym(evalTree{1});
            exprArray{1} = gpsimplify(fullExpr,simplifySteps,verReallyOld,fastMode);
            
            for i=2:length(evalTree);
                geneExpr = gp.results.best.returnvalues(i+1) * sym(evalTree{i});
                fullExpr = fullExpr+geneExpr;
                exprArray{i} = gpsimplify(geneExpr,simplifySteps,verReallyOld,fastMode);
            end
            
        end
        
    elseif ischar(ID) && strcmpi(ID,'valbest')
        
        % check that validation data is present
        if ~isfield(gp.results,'valbest')
            error('No validation data was found.');
        end
        
        if isempty(gp.results.valbest.returnvalues)
            gp.results.valbest.returnvalues(1) = 0;
            gp.results.valbest.returnvalues(2) = 1;
        end
        
        %knockout genes if required, this requires that coefficients are
        %recomputed on the training data
        if doknockout
            treestrs_eval = kogene(gp.results.valbest.eval_individual, knockout);
            treestrs = kogene(gp.results.valbest.individual, knockout);
            gp.state.run_completed = false;
            [~,gp,coeffs] = feval(gp.fitness.fitfun,treestrs_eval,gp);
            gp.results.valbest.returnvalues = coeffs;
            evalTree = gpreformat(gp,treestrs,useAlias);
        else
            evalTree = gpreformat(gp,gp.results.valbest.individual,useAlias);
        end
        
        if separateBias %bias is kept as a separate "gene"
            
            fullExpr = sym(gp.results.valbest.returnvalues(1));
            exprArray{1} = gpsimplify(fullExpr,simplifySteps,verReallyOld,fastMode);
            
            for i=1:length(evalTree);
                geneExpr = gp.results.valbest.returnvalues(i+1)*sym(evalTree{i});
                fullExpr = fullExpr+geneExpr;
                exprArray{i+1} = gpsimplify(geneExpr,simplifySteps,verReallyOld,fastMode);
            end
            
        else %normal processing (bias folded into first gene)
            fullExpr = gp.results.valbest.returnvalues(1) + gp.results.valbest.returnvalues(2)*sym(evalTree{1});
            exprArray{1} = gpsimplify(fullExpr,simplifySteps,verReallyOld,fastMode);
            
            for i=2:length(evalTree);
                geneExpr = gp.results.valbest.returnvalues(i+1) * sym(evalTree{i});
                fullExpr = fullExpr+geneExpr;
                exprArray{i} = gpsimplify(geneExpr,simplifySteps,verReallyOld,fastMode);
            end
            
        end
        
    elseif ischar(ID) && strcmpi(ID,'testbest')
        
        % check that validation data is present
        if ~isfield(gp.results,'testbest')
            error('No test data was found.');
        end
        
        if isempty(gp.results.testbest.returnvalues)
            gp.results.testbest.returnvalues(1) = 0;
            gp.results.testbest.returnvalues(2) = 1;
        end
        
        %knockout genes if required, this requires that coefficients are
        %recomputed on the training data
        if doknockout
            treestrs_eval = kogene(gp.results.testbest.eval_individual, knockout);
            treestrs = kogene(gp.results.testbest.individual, knockout);
            gp.state.run_completed = false;
            [~,gp,coeffs] = feval(gp.fitness.fitfun,treestrs_eval,gp);
            gp.results.testbest.returnvalues = coeffs;
            evalTree = gpreformat(gp,treestrs,useAlias);
        else
            evalTree = gpreformat(gp,gp.results.testbest.individual,useAlias);
        end
        
        if separateBias %bias is kept as a separate "gene"
            
            fullExpr = sym(gp.results.testbest.returnvalues(1));
            exprArray{1} = gpsimplify(fullExpr,simplifySteps,verReallyOld,fastMode);
            
            for i=1:length(evalTree);
                geneExpr = gp.results.testbest.returnvalues(i+1)*sym(evalTree{i});
                fullExpr = fullExpr+geneExpr;
                exprArray{i+1} = gpsimplify(geneExpr,simplifySteps,verReallyOld,fastMode);
            end
            
        else %normal processing (bias folded into first gene)
            fullExpr = gp.results.testbest.returnvalues(1) + gp.results.testbest.returnvalues(2)*sym(evalTree{1});
            exprArray{1} = gpsimplify(fullExpr,simplifySteps,verReallyOld,fastMode);
            
            for i=2:length(evalTree);
                geneExpr = gp.results.testbest.returnvalues(i+1) * sym(evalTree{i});
                fullExpr = fullExpr+geneExpr;
                exprArray{i} = gpsimplify(geneExpr,simplifySteps,verReallyOld,fastMode);
            end
            
        end
        
    elseif iscell(ID) %process cell array of encoded trees and rntVals
        %used, for instance, by gpgenes2model.m
        numGenes = numel(ID) - 1;
        evalTree = gpreformat(gp,{ID{1:numGenes}},useAlias);
        rtnVals = ID{end};
        fullExpr = rtnVals(1) + rtnVals(2)*sym(evalTree{1});
        exprArray = cell(1, numel(evalTree)+1);
        exprArray{1} = sym(rtnVals(1));
        
        for i=1:length(evalTree);
            geneExpr = rtnVals(i+1) * sym(evalTree{i});
            fullExpr = fullExpr + geneExpr;
            exprArray{i+1} = gpsimplify(geneExpr,simplifySteps,verReallyOld,fastMode);
        end
        
        %or process a gpmodel struct
    elseif isa(ID,'struct') && isfield(ID,'source') &&...
            (strcmpi(ID.source,'gpmodel2struct') || strcmpi(ID.source,'genes2GPmodel') );
        exprArray = ID.genes.geneSyms;
        fullExpr = ID.sym;
    else
        error('Illegal argument or unrecognised model selector');
    end
    
    %simplify the overall expression
    try
        fullExprSimplified = gpsimplify(fullExpr,2*simplifySteps,verReallyOld,fastMode);
    catch
        fullExprSimplified = fullExpr;
    end
    
    %et the display precision via Mupad
    if ~verReallyOld
        existingPrecision =  char(feval(symengine,'Pref::outputDigits'));
        evalin(symengine,'Pref::outputDigits(4)');
    end
    
    if nargout < 1
        
        if length(exprArray) > 1
            disp(' ');
            disp('Simplified genes');
            disp('----------------');
            disp(' ');
            disp('Gene 1 and bias term');
            pretty(vpa(exprArray{1},4));
            disp(' ');
            
            for a=2:length(exprArray)
                disp(['Gene ' int2str(a)]);
                pretty(vpa(exprArray{a},4));
                disp( ' ');
            end
        end
        
        disp('Simplified overall GP expression')
        disp('--------------------------------');
        pretty(vpa(fullExprSimplified,4));
    end
    
    if nargout > 0
        exprSym = fullExprSimplified;
    end
    
    if nargout > 1
        geneExprSym = exprArray;
    end
    
    if nargout > 2
        %process the LaTeX equation array line up the initial '=' and
        %subsequent '+' and '-' symbols that mark the start of a new gene
        %using &s
        exprs = exprArray;
        latexExpr = ['y=&&' deblank(latex(vpa(exprs{1},4)))]; %creates line up point for genes
        
        pat='x(\d+)';
        latexExpr = regexprep(latexExpr,pat,'x_{$1}');
        
        for i=2:length(exprs)
            lex = deblank(latex(vpa(exprs{i},4)));
            latexExpr = regexprep(latexExpr,pat,'x_{$1}');
            
            if lex(1) == '-'
                lex = lex(2:end);
                lex = ['&-&' lex]; %lines up the genes
                latexExpr = [latexExpr '\\' lex]; %starts next line in array
                
            else
                lex = lex(2:end);
                lex = ['&+&' lex];
                latexExpr = [latexExpr '\\' lex];
            end
        end
        
        geneLatexExpr = ['\begin{eqnarray*}' latexExpr '\end{eqnarray*}'];
    end
    
    if nargout > 2
        fullLatexExpr = ['y=' deblank(latex(vpa(fullExprSimplified,4)))];
        fullLatexExpr = regexprep(fullLatexExpr,pat,'x_{$1}');
    end
    
    %reset display precision to what it was
    if ~verReallyOld
        evalin(symengine,['Pref::outputDigits('  existingPrecision  ')']);
    end
    
else
    error('The Symbolic Math Toolbox is required to use this function.');
end