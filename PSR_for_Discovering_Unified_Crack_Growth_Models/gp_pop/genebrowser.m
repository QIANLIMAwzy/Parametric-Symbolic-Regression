function [modelGeneList, additionCandidate, additionR2, removalCandidate, removalR2] = genebrowser(gp,genes,ID,plotOption)
%GENEBROWSER Visually analyse unique genes in a population and identify horizontal bloat.
%
%   GENEBROWSER(GP,GENES,ID) launches the GENEBROWSER for the unique model
%   genes in GENES for the specified model. ID can be a numeric model
%   identifier in GP, or 'best', 'valbest' or 'testbest'. GENES is a data
%   struct obtained using either the UNIQUEGENES function or the GENEFILTER
%   function.
%
%   In the GENEBROWSER window model genes are displayed in blue and
%   non-model genes in red. The height of each bar indicates the
%   expressional complexity of the gene.
%
%   Clicking on a blue bar indicates the decrease in R^2 (on the training
%   data) that would occur if the corresponding gene was removed from the
%   MODEL. This can allow the identification of 'horizontal bloat', i.e.
%   genes that contribute very little to the overall prediction and may be
%   'safely' removed from the the model.
%
%   Clicking on a red bar indicates the increase in R^2 that would occur if
%   the corresponding gene was added to the model.
%
%   Hence, the GENEBROWSER allows the identification of improved models
%   that may not even exist in the orginal population.
%
%   GENEBROWSER(GP,GENES,MODEL,PLOTOPTION) where PLOTOPTION = 0 plots the
%   correlation coefficient of each gene with the output/response variable
%   (on the training data).
%
%   GENEBROWSER(GP,GENES,MODEL,PLOTOPTION) where PLOTOPTION = 1 plots the
%   expressional complexity of each gene (the default).
%
%   GENEBROWSER(GP,GENES,MODEL,PLOTOPTION) where PLOTOPTION = 2 plots the
%   gain in R^2 that would be acheived by adding the the plotted gene to
%   this model (on the training data).
%
%   Remarks:
%
%   This feature is somewhat experiental and user feedback on it would be
%   appreciated.
%
%   Copyright (c) 2009-2015 Dominic Searson
%   Copyright (c) 2023-2025 Chaoyang Wang
%   GPTIPS 2
%
%   See also UNIQUEGENES, GENEFILTER, GENES2GPMODEL

if nargin < 2
    disp('Usage is GENEBROWSER (GP,GENES,ID) where GENES');
    disp('is a structure generated by the UNIQUEGENES function')
    disp('(or GENEFILTER function) and ID is a numeric model identifier');
    disp('or ''best'' or ''valbest'' ');
    return;
end

if ~gp.info.toolbox.symbolic
    error('The Symbolic Math Toolbox is required to use this function.');
end

%plot best on training model genes in blue by default
if nargin < 3
    ID = 'best';
end

%plot expressional complexity by default
if nargin < 4
    plotOption = 1;
end

if plotOption < 0 || plotOption > 2
    error('plotOption must be 1 (model complexity), 0 (correlation coefficient) or 2 (R^2 gain).');
end

%if no model supplied use 'best'
if isempty(ID)
    ID = 'best';
end

if ~strncmpi(func2str(gp.fitness.fitfun),'regressmulti',12);
    error('This function is only for use on multigene regression models.');
end

%model selection
if isa(ID,'struct') && isfield(ID,'source') && (strcmpi(ID.source,'gpmodel2struct') || strcmpi(ID.source,'genes2gpmodel') );
    gpmodel = ID;
    modelstr = 'User model';
else
    modelstr = ID;
    if isnumeric(modelstr)
        modelstr = num2str(modelstr);
    end
    gpmodel = gpmodel2struct(gp, ID,false,false,true);
end

if ~gpmodel.valid
    error(['Selected model is invalid because: ' gpmodel.invalidReason]);
end

%get model genes
modelGenes = gpmodel.genes.geneStrs;

%get sym genes (w/o weights)
exprs = gpreformat(gp,modelGenes);
numModelGenes = numel(exprs);

symGenes = cell(1,numModelGenes);
symGenesChar = cell(numModelGenes,1);

verOld = verLessThan('matlab', '7.7.0');

for i=1:length(symGenes);
    symGenes{i} = gpsimplify(sym(exprs{i}),10,verOld,true);
    symGenesChar{i} = char(symGenes{i});
end

uniqueGenesChar = cell(genes.numUniqueGenes,1);

for i=1:numel(genes.uniqueGenesSym)
    uniqueGenesChar{i} = char(genes.uniqueGenesSym{i});
end

modelInds = zeros(1,numModelGenes);
for i=1:numModelGenes
    gene = symGenesChar{i};
    [~,~,mInd] = intersect(gene,uniqueGenesChar);
    if isempty(mInd)
        disp(['Warning: gene ' num2str(i) ' in the supplied model does not exist in the supplied unique gene set.']);
    else
        modelInds(i) = mInd;
    end
end

%full model info
fullModelR2 = gpmodel.train.r2;
fullModelComplexity = gpmodel.expComplexity;

%compute r2 for the model with each gene removed in turn
r2removed = zeros(numModelGenes,1);
gp.state.run_completed = true;
gp.state.force_compute_theta = true;
gp.runcontrol.pop_size = genes.numUniqueGenes;
gp.userdata.showgraphs = false;
gp.userdata.stats = false;
knockout = zeros(1,numModelGenes);

for i=1:numModelGenes
    knockout(i) = 1;
    evalstrs = tree2evalstr(modelGenes,gp);
    if numModelGenes > 1
        evalstrs = kogene(evalstrs, knockout);
    end
    
    [fitness,gp,~,~,~,~,~,r2train,~,~] = feval(gp.fitness.fitfun,evalstrs,gp);
    knockout(i)=0;
    
    if ~isinf(fitness)
        r2removed(i) = r2train;
        
        if numModelGenes == 1
            r2removed(i) = 0;
        end
    end
end
genes.r2removed = r2removed;

%compute r2 for the model with each non-model gene added
r2added = zeros(genes.numUniqueGenes,1);
for i=1:genes.numUniqueGenes
    
    if isempty(find(i == modelInds, 1));
        extModelGenes = horzcat(modelGenes, genes.uniqueGenesCoded{i});
        evalstrs = tree2evalstr(extModelGenes,gp);
        
        [fitness,gp,~,~,~,~,~,r2train,...
            ~,~] = feval(gp.fitness.fitfun,evalstrs,gp);
        
        if ~isinf(fitness)
            r2added(i) = r2train;
        end
    end
    
end
genes.r2added = r2added;

%list top candidate for gene removal from model
[maxRemovalR2,maxRemovalInd] = max(genes.r2removed);
maxRemovalInd = modelInds(maxRemovalInd);

%list top 5 candidate genes for addition to model
[additionsSorted, additionInds] = sort(genes.r2added,1,'descend');

additionInds = additionInds(1:5);

%if user requires then output stats for candidate addition and removal
%genes
if nargout >= 2
    additionCandidate = additionInds(1);
end

if nargout >= 3
    additionR2 = additionsSorted(1);
end

if nargout >= 4
    removalCandidate = maxRemovalInd;
end

if nargout >= 5
    removalR2 = maxRemovalR2;
end

fig = figure('numbertitle','off','visible','off','name',['GPTIPS 2 Gene and bloat analysis for model: ' modelstr]);

hg2 = false;
if ~verLessThan('matlab','8.4') %for versions >= 2014b (HG2)
    hg2 = true;
end

nonModelInds = setdiff(1:genes.numUniqueGenes,modelInds);
ax1 = subplot(2,1,1);
ax2 = subplot(2,1,2);

%remove model inds that are zero (e.g. if using filtered genes)
modelInds(modelInds == 0) = [];

%plot bars
if plotOption == 0 %corr. coef
    
    %bug in bar datacursor in R2014b so need to sort x
    barModelGenes = bar(ax1,sort(modelInds),genes.rtrain(sort(modelInds)),0.5);
    barNonModelGenes = bar(ax2,nonModelInds,genes.rtrain(nonModelInds),0.5);
    
elseif plotOption == 1 %expressional complexity (default)
    
    barModelGenes = bar(ax1,sort(modelInds),genes.complexity(sort(modelInds)),0.5);
    barNonModelGenes = bar(ax2,nonModelInds,genes.complexity(nonModelInds),0.5);
    
elseif plotOption == 2  %R2 change by additional or removal of gene from current model
    
    ax1 = subplot(1,1,1);
    barNonModelGenes = bar(ax1,nonModelInds,genes.r2added(nonModelInds),0.5);
    a = axis(ax1);
    a(3) = fullModelR2;
    axis(ax1,a);
else
    close(fig);
    error('Unrecognised plot option');
end

%modify appearance of bars and adjust axes
grid(ax1,'on');
if hg2
    barNonModelGenes.FaceColor = [0.85 0.33 0.1]; %orange
    barNonModelGenes.BaseLine.Visible = 'off';
    barNonModelGenes.EdgeColor  = 'none';
else
    set(barNonModelGenes,'FaceColor',[0.85 0.33 0.1]);
    set(barNonModelGenes,'EdgeColor','none');
end

if plotOption < 2
    
    grid(ax2,'on');
    
    if hg2
        barModelGenes.FaceColor = [0 0.45 0.74]; %light blue
        barModelGenes.EdgeColor = 'none';
        barModelGenes.BaseLine.Visible = 'off';
        
        ax2.XLim(2) = genes.numUniqueGenes+5;
        ax1.XLim(1) = 0;
        ax1.XLim(2) = ax2.XLim(2);
        ax2.XLim(1) = 0;
        ax1.XTick = ax2.XTick;
        ax1.XTickLabel = ax2.XTickLabel;
    else
        set(barModelGenes,'FaceColor',[0 0.45 0.74]);
        set(barModelGenes,'EdgeColor','none');
        ax1lims = axis(ax1);
        ax2lims = axis(ax2);
        axis(ax1,[0 genes.numUniqueGenes+5 ax1lims(3:4)]);
        axis(ax2,[0 genes.numUniqueGenes+5 ax2lims(3:4)]);
        ax2ticks = get(ax2,'Xtick');
        ax2tickLabels = get(ax2,'XtickLabel');
        set(ax1,'Xtick',ax2ticks);
        set(ax1,'XtickLabel',ax2tickLabels);
    end
end

if plotOption < 2
    xlabel(ax1,{'Unique gene number (model genes)',' ',['Model gene list: ' num2str(modelInds)],['Top gene candidate for removal from model: ' num2str(maxRemovalInd)]});
    xlabel(ax2, {'Unique gene number (non-model genes)',' ',['Top gene candidate for addition to model: ' num2str(additionInds(1))]});
else
    xlabel(ax1, {'Unique gene number (non-model genes)',' ',['Top gene candidate for addition to model: ' num2str(additionInds(1))]});
end

if plotOption == 0
    ylabel(ax1,'Abs. correlation coefficient {\bf r}');
    ylabel(ax2,'Abs. correlation coefficient {\bf r}');
elseif plotOption == 1
    ylabel(ax1,'Expressional complexity');
    ylabel(ax2,'Expressional complexity');
else
    ylabel(ax1,'R^2 gain');
end

mergeStr=' ';
if gp.info.merged && gp.info.filtered
    mergeStr=' (merged & filtered) ';
elseif gp.info.merged
    mergeStr=' (merged) ';
elseif gp.info.filtered
    mergeStr=' (filtered) ';
end

if ~isempty(gp.userdata.name)
    setname = ['Data set: ' gp.userdata.name];
else
    setname = '';
end

title(ax1,{['Population' mergeStr '(' num2str(gp.runcontrol.pop_size) ' genes). ' setname],...
    ['Selected model (ID = ' modelstr ') contains ' num2str(gpmodel.genes.num_genes) ' genes. R^2: ' num2str(fullModelR2) ' Complexity: ' num2str(fullModelComplexity)],...
    },'fontWeight','bold');
disp('');

genes.modelInds = modelInds;
genes.verOld = verOld;

%enable datacursor
set(gcf,'userdata',genes);
dcm_obj = datacursormode(gcf);
set(dcm_obj,'UpdateFcn',@disp_gene);
set(dcm_obj,'SnapToDataVertex','on');
set(dcm_obj,'enable','on');

set(fig,'visible','on');

if nargout > 0
    modelGeneList = modelInds;
end

function txt=disp_gene(~,event_obj)
%Function to return gene info to datacursor.

%hg2 workaround
if verLessThan('Matlab','8.4')
    genes = get(gcbf,'userdata'); %oddly, appears not to work in 2014b
    a = get(event_obj);
    b = get(a.Target);
    barDetected = strcmp(b.Type,'hggroup');
else
    genes = get(gcf,'userdata');
    a = get(event_obj);
    b = a.Target;
    barDetected = isa(b,'matlab.graphics.chart.primitive.Bar');
end

if barDetected
    geneNum = a.Position(1);
    txt = cell(2);
    txt{1} = ['Gene ' num2str(geneNum)];
    
    txt{2} = char(genes.uniqueGenesSym{geneNum});
    
    %check if gene is in model or not
    a = find(geneNum == genes.modelInds);
    
    if ~isempty(a)
        txt{3} = ' ';
        txt{4} = ['Gene ' num2str(a) ' in model.'];
        txt{5} = ' ';
        txt{6} = ['Model R^2 without gene: ' num2str(genes.r2removed(a(1)))];
    else
        txt{3} = ' ';
        txt{4} = ['Model R^2 with gene: ' num2str(genes.r2added(geneNum))];
    end
else
    txt = '';
end