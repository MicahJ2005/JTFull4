import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getWorkflowsForMatter from '@salesforce/apex/MatterTaskTrackerController.getWorkflowsForMatter';
import completeTask          from '@salesforce/apex/MatterTaskTrackerController.completeTask';
import reopenTask            from '@salesforce/apex/MatterTaskTrackerController.reopenTask';
import updateTaskDueDate     from '@salesforce/apex/MatterTaskTrackerController.updateTaskDueDate';
import updateTaskOwner       from '@salesforce/apex/MatterTaskTrackerController.updateTaskOwner';

// â”€â”€ Swimlane layout constants â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const LANE_LABEL_WIDTH    = 230;   // role label column width
const LANE_PAD            = 10;    // top/bottom padding inside a lane
const LANE_MIN_H          = 72;    // minimum lane height
const PHASE_COL_W         = 220;   // expanded phase column width
const PHASE_COL_COLLAPSED = 36;    // collapsed phase column width
const CELL_PAD            = 8;     // padding inside a phaseÃ—role cell
const CELL_TASK_H         = 46;    // task card height
const CELL_TASK_GAP       = 6;     // vertical gap between task cards
const GROUP_HEADER_H      = 24;    // parent-phase group label band height
const PHASE_HEADER_H      = 38;    // phase column header band height
const DEADLINE_LABEL_H    = 28;    // space below lanes for deadline labels

// â”€â”€ Gantt layout constants â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const GANTT_HEADER_H      = 68;
const GANTT_ROW_HEIGHT    = 56;
const GANTT_LABEL_WIDTH   = 240;
const GANTT_DAY_WIDTH     = 12;
const GANTT_MIN_BAR       = 110;

// â”€â”€ Color palettes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const ROLE_COLORS = {
    Attorney:             { bg: '#7A9B7E', border: '#5A7B5E', bgLight: '#E8F0E9', text: '#5A7B5E' },
    Paralegal:            { bg: '#2878A6', border: '#1F5E85', bgLight: '#D8E8F5', text: '#1F5E85' },
    'Paralegal Assistant':{ bg: '#C4885A', border: '#9E6438', bgLight: '#FAE8D5', text: '#9E6438' },
    CSS:                  { bg: '#5B9B9B', border: '#447777', bgLight: '#D8F0F0', text: '#447777' },
    Client:               { bg: '#C07058', border: '#9A5544', bgLight: '#F5E0D8', text: '#9A5544' }
};
const DEFAULT_COLORS = { bg: '#7B68AA', border: '#5E4D8E', bgLight: '#EBE8F5', text: '#5E4D8E' };

const PHASE_COLORS = [
    { solid: 'rgba(122,155,126,0.70)', bg: 'rgba(122,155,126,0.07)' },
    { solid: 'rgba(40,120,166,0.70)',  bg: 'rgba(40,120,166,0.07)'  },
    { solid: 'rgba(192,112,88,0.70)',  bg: 'rgba(192,112,88,0.07)'  },
    { solid: 'rgba(212,168,83,0.70)',  bg: 'rgba(212,168,83,0.07)'  },
    { solid: 'rgba(91,155,155,0.70)',  bg: 'rgba(91,155,155,0.07)'  }
];

const VIEW_OPTIONS = [
    { id: 'swimlane', label: 'Swimlane'       },
    { id: 'gantt',    label: 'Gantt'          },
    { id: 'mytasks',  label: 'My Tasks'       },
    { id: 'summary',  label: 'Status Summary' }
];


// Canonical role row order â€” roles not listed here fall back to alphabetical
const ROLE_ORDER = ['Attorney', 'Paralegal', 'CSS', 'Client'];

// â”€â”€ Pure helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const PENDING_STATUS = 'Waiting On Other Tasks';

const ROLE_DISPLAY = { 'Paralegal Assistant': 'Client Support Specialist' };
function displayRole(role) { return ROLE_DISPLAY[role] || role; }

function rc(role) {
    return ROLE_COLORS[role] || DEFAULT_COLORS;
}

function isPending(task) {
    return !task.isComplete && task.status === PENDING_STATUS;
}

function isVoided(task) {
    return task.status === 'Terminated' || task.status === 'Refund';
}

function formatDate(val) {
    if (!val) return null;
    const d = new Date(val + 'T00:00:00Z');
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' });
}

function svgEl(tag, attrs) {
    const el = document.createElementNS('http://www.w3.org/2000/svg', tag);
    if (attrs) {
        for (const [k, v] of Object.entries(attrs)) {
            el.setAttribute(k, String(v));
        }
    }
    return el;
}

function trunc(str, maxLen) {
    if (!str) return '';
    return str.length > maxLen ? str.substring(0, maxLen - 1) + '…' : str;
}

function flatTasks(wf) {
    return (wf.phases || []).flatMap(p => p.tasks || []);
}

// â”€â”€ Component â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
export default class MatterTaskTracker extends NavigationMixin(LightningElement) {
    @api recordId;

    @track workflowViews       = [];
    @track isLoading           = true;
    @track isEmpty             = false;
    @track error;
    @track selectedTask;
    @track isEditingDueDate    = false;
    @track pendingDueDate      = null;
    @track isEditingOwner        = false;
    @track pendingOwnerId        = null;
    @track hoverTooltip;

    _wiredResult;
    _rawBundle;
    _wfState     = {};
    _taskIndex   = {};
    _tooltipOnly = false;
    _lastTipId;

    // â”€â”€ Wire â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @wire(getWorkflowsForMatter, { matterId: '$recordId' })
    wiredData(result) {
        this._wiredResult = result;
        this.isLoading = false;
        const { data, error } = result;
        if (data) {
            this._rawBundle = data;
            this.error = null;
            this._buildAll();
        } else if (error) {
            this.error = (error.body && error.body.message) ? error.body.message : 'An unexpected error occurred.';
            this.workflowViews = [];
            this.isEmpty = false;
        }
    }

    // â”€â”€ Lifecycle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    renderedCallback() {
        if (this._tooltipOnly) {
            this._tooltipOnly = false;
            return;
        }
        this._renderAllSvgs();
    }

    // â”€â”€ Build view model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    _buildAll() {
        const bundle = this._rawBundle;
        if (!bundle || !bundle.workflows || bundle.workflows.length === 0) {
            this.isEmpty = true;
            this.workflowViews = [];
            return;
        }
        this.isEmpty = false;

        this._taskIndex = {};
        bundle.workflows.forEach(wf => {
            (wf.phases || []).forEach(phase => {
                (phase.tasks || []).forEach(task => {
                    this._taskIndex[task.id] = { task, workflowId: wf.id, phaseName: phase.name, phaseId: phase.id };
                });
            });
        });

        bundle.workflows.forEach(wf => {
            if (!this._wfState[wf.id]) {
                this._wfState[wf.id] = {
                    isOpen:          false,
                    activeView:      'swimlane',
                    roleFilter:      null,
                    showCompleted:   false,
                    myTasksRole:     null,
                    collapsedPhases: new Set()
                };
            }
        });

        this.workflowViews = bundle.workflows.map(wf => this._buildWfView(wf));
    }

    _rebuild() {
        if (!this._rawBundle) return;
        this.workflowViews = this._rawBundle.workflows.map(wf => this._buildWfView(wf));
    }

    _buildWfView(wf) {
        const st      = this._wfState[wf.id];
        const all     = flatTasks(wf);
        const nonDead = all.filter(t => !t.isDeadline);

        const done  = nonDead.filter(t => t.isComplete).length;
        const total = nonDead.length;
        const pct   = total > 0 ? Math.round(done / total * 100) : 0;

        const roles   = this._collectRoles(wf);
        const maxDay  = this._maxDay(wf);
        const tDays   = maxDay + 5;

        // Compute sorted + leaf phases once â€” reused for swimlane layout and phase summaries.
        const wfIdStr    = String(wf.id || '');
        const sorted     = this._sortPhases(wf.phases || [], wf.id);
        const leafPhases = this._getLeafPhases(sorted, wfIdStr);
        const colW       = leafPhases.map(p =>
            st.collapsedPhases && st.collapsedPhases.has(p.id) ? PHASE_COL_COLLAPSED : PHASE_COL_W
        );
        const chartW = Math.max(LANE_LABEL_WIDTH + colW.reduce((a, b) => a + b, 0), 700);
        const chartH = this._computeChartH_matrix(wf, roles, st);

        // Gantt: day-timeline (height accounts for role filter)
        const ganttTasks = nonDead.filter(t => (!st.roleFilter || t.role === st.roleFilter) && (st.showCompleted || !t.isComplete));
        const ganttW = Math.max(GANTT_LABEL_WIDTH + tDays * GANTT_DAY_WIDTH + GANTT_MIN_BAR + 20, 700);
        const ganttH = GANTT_HEADER_H + ganttTasks.length * GANTT_ROW_HEIGHT + 20;

        const myRole = st.myTasksRole || null;  // null = All roles

        const myTasks = nonDead
            .filter(t => myRole ? t.role === myRole : true)
            .slice()
            .sort((a, b) => {
                if (!a.dueDate && !b.dueDate) return 0;
                if (!a.dueDate) return 1;
                if (!b.dueDate) return -1;
                return new Date(a.dueDate) - new Date(b.dueDate);
            })
            .map(t => {
                const c      = rc(t.role);
                const isDone = t.isComplete;
                const isPend = isPending(t);
                return {
                    id:              t.id,
                    name:            t.name,
                    phaseName:       (this._taskIndex[t.id] || {}).phaseName || '',
                    dueDateLabel:    formatDate(t.dueDate),
                    cardClass:       'mytask-card' + (isDone ? ' mytask-card-done' : ''),
                    cardStyle:       `border-left:4px solid ${c.bg};`,
                    statusIcon:      isDone ? 'utility:check' : (isPend ? 'utility:date_input' : 'utility:clock'),
                    statusIconClass: isDone ? 'status-icon-done' : 'status-icon'
                };
            });

        const roleSummaries = roles.map(role => {
            const c   = rc(role);
            const rt  = nonDead.filter(t => t.role === role);
            const rcd = rt.filter(t => t.isComplete).length;
            const rp  = rt.length ? Math.round(rcd / rt.length * 100) : 0;
            return {
                id:         role,
                label:      displayRole(role),
                dotStyle:   `background:${c.bg};`,
                fillStyle:  `width:${rp}%;background:${c.bg};`,
                countLabel: `${rcd} / ${rt.length}`
            };
        });

        // By-phase breakdown (leaf phases only â€” those with tasks)
        const phaseSummaries = leafPhases
            .map(phase => {
                const pt  = (phase.tasks || []).filter(t => !t.isDeadline);
                const pcd = pt.filter(t => t.isComplete).length;
                const pp  = pt.length ? Math.round(pcd / pt.length * 100) : 0;
                return {
                    id:         phase.id,
                    name:       phase.name,
                    fillStyle:  `width:${pp}%;background:#7A9B7E;`,
                    countLabel: `${pcd} / ${pt.length}`
                };
            })
            .filter(p => p.countLabel !== '0 / 0');

        const rolePills = roles.map(role => {
            const c        = rc(role);
            const isActive = st.roleFilter === role;
            const isTab    = myRole === role;
            return {
                id:        role,
                label:     displayRole(role),
                pillClass: 'role-pill' + (isActive ? ' role-pill-active' : ''),
                pillStyle: isActive ? `background:${c.bg};color:#fff;border-color:${c.border};` : '',
                tabClass:  'mytasks-tab' + (isTab ? ' mytasks-tab-active' : ''),
                tabStyle:  isTab ? `background:${c.bg};color:#fff;border-color:${c.border};` : ''
            };
        });

        const viewOptions = VIEW_OPTIONS.map(opt => ({
            ...opt,
            btnClass: 'view-btn' + (st.activeView === opt.id ? ' view-btn-active' : '')
        }));

        const isSwimlane = st.activeView === 'swimlane';
        const isGantt    = st.activeView === 'gantt';

        return {
            id:             wf.id,
            name:           wf.name,
            isOpen:         st.isOpen,
            chevronClass:   'chevron' + (st.isOpen ? ' chevron-open' : ''),
            progressStyle:  `width:${pct}%;background:#7A9B7E;`,
            completedCount: done,
            totalCount:     total,
            remainingCount: total - done,
            viewOptions,
            isSwimlane,
            isGantt,
            isMyTasks:       st.activeView === 'mytasks',
            isSummary:       st.activeView === 'summary',
            showControlsRow: isSwimlane || isGantt,
            myTasksAllTabClass: 'mytasks-tab' + (!st.myTasksRole ? ' mytasks-tab-active' : ''),
            allPillClass:   'role-pill-all role-pill' + (!st.roleFilter ? ' role-pill-active' : ''),
            rolePills,
            showCompleted:        st.showCompleted,
            showCompletedToggle:  isSwimlane || isGantt,
            completedBtnClass:    'deps-btn' + (st.showCompleted ? ' deps-btn-on' : ''),
            chartWidth:     chartW,
            chartHeight:    chartH,
            ganttWidth:     ganttW,
            ganttHeight:    ganttH,
            myTasks,
            roleSummaries,
            phaseSummaries,
            overallLabel:     `${done} / ${total} tasks complete · ${pct}%`,
            overallFillStyle: `width:${pct}%;background:#7A9B7E;`,
            _wf:     wf,
            _state:  st,
            _roles:  roles,
            _maxDay: maxDay
        };
    }

    _collectRoles(wf) {
        const seen = new Set();
        (wf.phases || []).forEach(p => {
            (p.tasks || []).forEach(t => {
                if (t.role && !t.isDeadline) seen.add(t.role);
            });
        });
        return [...seen].sort((a, b) => {
            const ai = ROLE_ORDER.indexOf(a);
            const bi = ROLE_ORDER.indexOf(b);
            if (ai !== -1 && bi !== -1) return ai - bi;
            if (ai !== -1) return -1;
            if (bi !== -1) return 1;
            return a.localeCompare(b);
        });
    }

    // Returns only phases that render as columns (those that have no sub-phases).
    _getLeafPhases(sortedPhases, wfIdStr) {
        const parentIds = new Set(
            sortedPhases
                .filter(p => p.parentCaseId && p.parentCaseId !== wfIdStr)
                .map(p => String(p.parentCaseId))
        );
        return sortedPhases.filter(p => !parentIds.has(String(p.id)));
    }

    _computeChartH_matrix(wf, roles, st) {
        const wfIdStr    = String(wf.id || '');
        const sorted     = this._sortPhases(wf.phases || [], wf.id);
        const leafPhases = this._getLeafPhases(sorted, wfIdStr);
        const seenP = new Set(); const extraT = {};
        leafPhases.forEach(phase => {
            if (!phase.parentCaseId || phase.parentCaseId === wfIdStr) return;
            const pid = String(phase.parentCaseId);
            if (seenP.has(pid)) return;
            seenP.add(pid);
            const pp = sorted.find(p => String(p.id) === pid);
            if (pp && (pp.tasks || []).length > 0) extraT[phase.id] = pp.tasks;
        });
        const phAll = phase => [...(extraT[phase.id] || []), ...(phase.tasks || [])];
        const laneH      = roles.map(role => {
            let maxTasks = 0;
            leafPhases.forEach(phase => {
                if (st.collapsedPhases && st.collapsedPhases.has(phase.id)) return;
                const count = phAll(phase).filter(
                    t => !t.isDeadline && t.role === role && (st.showCompleted || !t.isComplete)
                ).length;
                maxTasks = Math.max(maxTasks, count);
            });
            return Math.max(
                LANE_PAD + maxTasks * (CELL_TASK_H + CELL_TASK_GAP) + LANE_PAD,
                LANE_MIN_H
            );
        });
        const hasDeadlines = leafPhases.some(p => phAll(p).some(t => t.isDeadline));
        return GROUP_HEADER_H + PHASE_HEADER_H + laneH.reduce((a, b) => a + b, 0) + (hasDeadlines ? DEADLINE_LABEL_H : 10);
    }

    // Returns phases sorted depth-first: root phases in Order__c order,
    // each immediately followed by its children (also in Order__c order).
    _sortPhases(phases, wfId) {
        if (!phases || !phases.length) return phases || [];
        try {
            const root     = String(wfId || '');
            const byParent = {};
            phases.forEach(p => {
                // A phase is a root-level phase if parentCaseId equals the workflow case ID
                // or if parentCaseId is missing/null.
                const key = (p.parentCaseId && p.parentCaseId !== root)
                    ? String(p.parentCaseId) : root;
                if (!byParent[key]) byParent[key] = [];
                byParent[key].push(p);
            });
            Object.values(byParent).forEach(arr =>
                arr.sort((a, b) => (a.orderIndex || 0) - (b.orderIndex || 0))
            );
            const result  = [];
            const seen    = new Set();   // cycle protection
            const visit   = id => {
                if (seen.has(id)) return;
                seen.add(id);
                (byParent[id] || []).forEach(p => { result.push(p); visit(String(p.id)); });
            };
            visit(root);
            // orphan safety net â€” use id comparison, not reference equality
            const seenIds = new Set(result.map(p => p.id));
            phases.forEach(p => { if (!seenIds.has(p.id)) result.push(p); });
            return result;
        } catch (e) {
            return [...phases]; // fallback: return original order
        }
    }

    _maxDay(wf) {
        let max = 30;
        (wf.phases || []).forEach(p => {
            (p.tasks || []).forEach(t => {
                if (t.dayOffset != null) {
                    max = Math.max(max, (t.dayOffset || 0) + (t.duration || 1));
                }
            });
        });
        return max;
    }

    // â”€â”€ SVG rendering â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    _renderAllSvgs() {
        if (!this._rawBundle) return;
        (this.workflowViews || []).forEach(wfv => {
            if (!wfv.isOpen) return;
            if (wfv.isSwimlane) {
                const el = this.template.querySelector(`[data-chart-id="${wfv.id}"]`);
                if (el) this._renderSwimlane(el, wfv);
            }
            if (wfv.isGantt) {
                const el = this.template.querySelector(`[data-gantt-id="${wfv.id}"]`);
                if (el) this._renderGantt(el, wfv);
            }
        });
    }

    _renderSwimlane(svg, wfv) {
        while (svg.firstChild) svg.removeChild(svg.firstChild);

        const wf      = wfv._wf;
        const st      = wfv._state;
        const roles   = wfv._roles;
        const wfIdStr = String(wf.id || '');
        const all     = flatTasks(wf);
        const nonDead = all.filter(t => !t.isDeadline);
        const deads   = all.filter(t => t.isDeadline);
        const visSet = new Set(
            nonDead
                .filter(t => (!st.roleFilter || t.role === st.roleFilter) && (st.showCompleted || !t.isComplete))
                .map(t => t.id)
        );

        // All phases sorted depth-first; only leaf phases become columns
        const sortedPhases = this._sortPhases(wf.phases || [], wf.id);
        const leafPhases   = this._getLeafPhases(sortedPhases, wfIdStr);

        // Fold tasks from parent/group phases into the first leaf child of each group.
        // Tasks linked directly to a parent case (e.g. "Case Development") have no column
        // of their own; surfacing them in the first leaf column makes them visible.
        const _seenP = new Set(); const _extraT = {};
        leafPhases.forEach(phase => {
            if (!phase.parentCaseId || phase.parentCaseId === wfIdStr) return;
            const pid = String(phase.parentCaseId);
            if (_seenP.has(pid)) return;
            _seenP.add(pid);
            const pp = sortedPhases.find(p => String(p.id) === pid);
            if (pp && (pp.tasks || []).length > 0) _extraT[phase.id] = pp.tasks;
        });
        const phAll = phase => [...(_extraT[phase.id] || []), ...(phase.tasks || [])];

        // Column widths + X positions (leaf phases only)
        const colW = leafPhases.map(p =>
            st.collapsedPhases && st.collapsedPhases.has(p.id) ? PHASE_COL_COLLAPSED : PHASE_COL_W
        );
        const colX = [];
        let cxp = LANE_LABEL_WIDTH;
        leafPhases.forEach((_, pi) => { colX.push(cxp); cxp += colW[pi]; });
        const totalW = Math.max(cxp, 700);

        // Color assignment: sibling sub-phases share the same color slot
        let   colorCounter  = 0;
        const groupColorMap = {}; // parentId â†' color index
        const phaseColorIdx = {}; // phaseId  â†' color index
        leafPhases.forEach(phase => {
            const isSubPhase = phase.parentCaseId && phase.parentCaseId !== wfIdStr;
            if (!isSubPhase) {
                phaseColorIdx[phase.id] = colorCounter++;
            } else {
                const gKey = String(phase.parentCaseId);
                if (groupColorMap[gKey] === undefined) groupColorMap[gKey] = colorCounter++;
                phaseColorIdx[phase.id] = groupColorMap[gKey];
            }
        });

        // Role lane heights (based on task count in leaf phases)
        const laneH = roles.map(role => {
            let maxTasks = 0;
            leafPhases.forEach((phase, pi) => {
                if (colW[pi] === PHASE_COL_COLLAPSED) return;
                const count = phAll(phase).filter(
                    t => !t.isDeadline && t.role === role && visSet.has(t.id)
                ).length;
                maxTasks = Math.max(maxTasks, count);
            });
            return Math.max(LANE_PAD + maxTasks * (CELL_TASK_H + CELL_TASK_GAP) + LANE_PAD, LANE_MIN_H);
        });

        const laneY = [];
        let cly = GROUP_HEADER_H + PHASE_HEADER_H;
        roles.forEach((_, ri) => { laneY.push(cly); cly += laneH[ri]; });
        const lanesBottom = cly;
        const totalH      = lanesBottom + (deads.length ? DEADLINE_LABEL_H : 10);

        svg.setAttribute('width',  totalW);
        svg.setAttribute('height', totalH);

        // â”€â”€ Lane stripe backgrounds + role pills â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        roles.forEach((role, ri) => {
            const y  = laneY[ri];
            const lh = laneH[ri];
            const c  = rc(role);
            svg.appendChild(svgEl('rect', {
                x: 0, y, width: totalW, height: lh,
                fill: ri % 2 === 0 ? '#f9fafb' : '#ffffff'
            }));
            svg.appendChild(svgEl('line', {
                x1: 0, y1: y, x2: totalW, y2: y,
                stroke: '#e5e7eb', 'stroke-width': '0.5'
            }));
            const pillW = LANE_LABEL_WIDTH - 20;
            const pillH = Math.min(36, lh - 12);
            const pillY = y + (lh - pillH) / 2;
            svg.appendChild(svgEl('rect', {
                x: 10, y: pillY, width: pillW, height: pillH,
                rx: 8, fill: c.bg, stroke: c.border, 'stroke-width': '1.5'
            }));
            const pt = svgEl('text', {
                x: LANE_LABEL_WIDTH / 2, y: pillY + pillH / 2 + 5,
                'text-anchor': 'middle', 'font-size': '13', 'font-weight': '600',
                fill: '#fff', 'font-family': 'Salesforce Sans,Arial,sans-serif'
            });
            pt.textContent = trunc(displayRole(role), Math.floor((pillW - 16) / 7.5));
            svg.appendChild(pt);
        });

        // â”€â”€ Group header band (top strip) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        // Light neutral background across the whole group-header area
        svg.appendChild(svgEl('rect', {
            x: LANE_LABEL_WIDTH, y: 0,
            width: totalW - LANE_LABEL_WIDTH, height: GROUP_HEADER_H,
            fill: '#f0f2f5'
        }));

        // Build group spans: parentPhaseId â†' { x, w, name, colorIdx }
        const groupSpan = {};
        leafPhases.forEach((phase, pi) => {
            const isSubPhase = phase.parentCaseId && phase.parentCaseId !== wfIdStr;
            if (!isSubPhase) return;
            const parentId = String(phase.parentCaseId);
            if (!groupSpan[parentId]) {
                const parentPhase = sortedPhases.find(p => String(p.id) === parentId);
                groupSpan[parentId] = {
                    x:        colX[pi],
                    w:        colW[pi],
                    name:     parentPhase ? parentPhase.name : '',
                    colorIdx: groupColorMap[parentId]
                };
            } else {
                groupSpan[parentId].w += colW[pi];
            }
        });

        // Draw each group span as a colored bar with the parent phase name
        Object.values(groupSpan).forEach(span => {
            const pc = PHASE_COLORS[(span.colorIdx || 0) % PHASE_COLORS.length];
            svg.appendChild(svgEl('rect', {
                x: span.x, y: 0, width: span.w, height: GROUP_HEADER_H,
                fill: pc.solid
            }));
            // Left separator line
            svg.appendChild(svgEl('line', {
                x1: span.x, y1: 0, x2: span.x, y2: GROUP_HEADER_H,
                stroke: 'rgba(0,0,0,0.12)', 'stroke-width': '1'
            }));
            const lbl = svgEl('text', {
                x: span.x + span.w / 2, y: GROUP_HEADER_H / 2 + 4,
                'text-anchor': 'middle', 'font-size': '11', 'font-weight': '700',
                fill: '#fff', 'font-family': 'Salesforce Sans,Arial,sans-serif'
            });
            lbl.textContent = trunc(span.name, Math.floor(span.w / 7));
            svg.appendChild(lbl);
        });

        // â”€â”€ Phase column backgrounds + headers (leaf phases) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        leafPhases.forEach((phase, pi) => {
            const ci  = phaseColorIdx[phase.id] || 0;
            const pc  = PHASE_COLORS[ci % PHASE_COLORS.length];
            const px  = colX[pi];
            const pw  = colW[pi];
            const collapsed = st.collapsedPhases && st.collapsedPhases.has(phase.id);

            // Column tint for lane rows
            svg.appendChild(svgEl('rect', {
                x: px, y: GROUP_HEADER_H + PHASE_HEADER_H,
                width: pw, height: lanesBottom - GROUP_HEADER_H - PHASE_HEADER_H,
                fill: pc.bg
            }));
            // Vertical separator (full height, below group band)
            svg.appendChild(svgEl('line', {
                x1: px, y1: GROUP_HEADER_H, x2: px, y2: lanesBottom,
                stroke: 'rgba(0,0,0,0.10)', 'stroke-width': '1'
            }));
            // Phase header band (below group band)
            svg.appendChild(svgEl('rect', {
                x: px, y: GROUP_HEADER_H, width: pw, height: PHASE_HEADER_H,
                fill: pc.solid
            }));

            const wfIdL = wf.id;
            const phId  = phase.id;

            if (collapsed) {
                const plus = svgEl('text', {
                    x: px + pw / 2, y: GROUP_HEADER_H + PHASE_HEADER_H / 2 + 5,
                    'text-anchor': 'middle', 'font-size': '18', 'font-weight': '700',
                    fill: '#fff', 'font-family': 'Salesforce Sans,Arial,sans-serif'
                });
                plus.textContent = '+';
                svg.appendChild(plus);
                const overlay = svgEl('rect', {
                    x: px, y: GROUP_HEADER_H, width: pw,
                    height: lanesBottom - GROUP_HEADER_H,
                    fill: 'rgba(0,0,0,0.001)', style: 'cursor:pointer'
                });
                overlay.addEventListener('click', () => this._togglePhase(wfIdL, phId));
                svg.appendChild(overlay);
            } else {
                const maxCh = Math.floor((pw - 34) / 7.5);
                const lbl   = svgEl('text', {
                    x: px + 10, y: GROUP_HEADER_H + PHASE_HEADER_H / 2 + 5,
                    'font-size': '12', 'font-weight': '700',
                    fill: '#fff', 'font-family': 'Salesforce Sans,Arial,sans-serif'
                });
                lbl.textContent = trunc(phase.name, maxCh);
                svg.appendChild(lbl);
                const btn = svgEl('g', { style: 'cursor:pointer' });
                btn.appendChild(svgEl('circle', {
                    cx: px + pw - 16, cy: GROUP_HEADER_H + PHASE_HEADER_H / 2, r: 10,
                    fill: 'rgba(255,255,255,0.22)'
                }));
                const bt = svgEl('text', {
                    x: px + pw - 16, y: GROUP_HEADER_H + PHASE_HEADER_H / 2 + 5,
                    'text-anchor': 'middle', 'font-size': '16', 'font-weight': '700',
                    fill: '#fff', 'font-family': 'Salesforce Sans,Arial,sans-serif'
                });
                bt.textContent = '-';
                btn.appendChild(bt);
                btn.addEventListener('click', () => this._togglePhase(wfIdL, phId));
                svg.appendChild(btn);
            }
        });

        // Dependency curves intentionally omitted — deps shown in task panel only

        // â”€â”€ Task cards â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        leafPhases.forEach((phase, pi) => {
            if (colW[pi] === PHASE_COL_COLLAPSED) return;
            const px = colX[pi];
            const pw = colW[pi];
            const tw = pw - 2 * CELL_PAD;

            roles.forEach((role, ri) => {
                const ly        = laneY[ri];
                const cellTasks = phAll(phase).filter(
                    t => !t.isDeadline && t.role === role && visSet.has(t.id)
                );
                cellTasks.forEach((task, ti) => {
                    const tx   = px + CELL_PAD;
                    const ty   = ly + LANE_PAD + ti * (CELL_TASK_H + CELL_TASK_GAP);
                    const th   = CELL_TASK_H;
                    const c2       = rc(task.role);
                    const done     = task.isComplete;
                    const voided   = isVoided(task);
                    const pend     = isPending(task);
                    const hasDueDate = !!task.dueDate;   // ActivityDate set

                    let fill, stroke, textFill, cardDash;
                    if (voided) {
                        fill = '#374151'; stroke = '#1f2937'; textFill = '#9ca3af';
                    } else if (done) {
                        fill = '#8f989c'; stroke = '#6f7a7e'; textFill = '#fff';
                    } else if (!hasDueDate) {
                        fill = c2.bgLight; stroke = c2.border; textFill = c2.text; cardDash = '6,3';
                    } else {
                        fill = c2.bg; stroke = c2.border; textFill = '#fff';
                    }

                    const g = svgEl('g', { style: 'cursor:pointer' });
                    const cardAttrs = { x: tx, y: ty, width: tw, height: th, rx: 6, fill, stroke, 'stroke-width': '2' };
                    if (cardDash) cardAttrs['stroke-dasharray'] = cardDash;
                    g.appendChild(svgEl('rect', cardAttrs));
                    if (done && !voided) {
                        g.appendChild(svgEl('circle', {
                            cx: tx + tw - 12, cy: ty + 12, r: 9,
                            fill: '#fff', opacity: '0.9'
                        }));
                        const ck = svgEl('text', {
                            x: tx + tw - 12, y: ty + 17,
                            'text-anchor': 'middle', 'font-size': '11',
                            fill: '#6f7a7e', 'font-family': 'Salesforce Sans,Arial,sans-serif'
                        });
                        ck.textContent = '✓';
                        g.appendChild(ck);
                    }
                    const usedRight = (done && !voided) ? 26 : 8;
                    const maxCh2    = Math.max(Math.floor((tw - 10 - usedRight) / 6.5), 5);
                    const nameAttrs = {
                        x: tx + 8, y: ty + th / 2 - 4,
                        'font-size': '11', 'font-weight': '600',
                        fill: textFill, opacity: (pend && !hasDueDate) ? '0.8' : '1',
                        'font-family': 'Salesforce Sans,Arial,sans-serif'
                    };
                    if (voided) nameAttrs['text-decoration'] = 'line-through';
                    const nameEl = svgEl('text', nameAttrs);
                    nameEl.textContent = trunc(task.name, maxCh2);
                    g.appendChild(nameEl);
                    let dateLbl = 'No Due Date';
                    if (task.dueDate) {
                        const d = new Date(task.dueDate + 'T00:00:00Z');
                        dateLbl = `${d.getUTCMonth() + 1}/${d.getUTCDate()}/${d.getUTCFullYear()}`;
                    }
                    const dayEl = svgEl('text', {
                        x: tx + 8, y: ty + th / 2 + 12,
                        'font-size': '9', fill: textFill, opacity: task.dueDate ? '0.72' : '0.55',
                        'font-family': 'Salesforce Sans,Arial,sans-serif'
                    });
                    dayEl.textContent = dateLbl;
                    g.appendChild(dayEl);
                    const tid   = task.id;
                    const tsnap = { ...task };
                    g.addEventListener('click',     ()  => this._openTask(tid));
                    g.addEventListener('mouseover', (e) => this._showTip(e, tsnap));
                    g.addEventListener('mouseout',  ()  => this._hideTip());
                    svg.appendChild(g);
                });
            });
        });

        // â”€â”€ Deadline markers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        deads.forEach(task => {
            const phaseIdx = leafPhases.findIndex(p => phAll(p).some(t => t.id === task.id));
            if (phaseIdx === -1) return;
            if (st.collapsedPhases && st.collapsedPhases.has(leafPhases[phaseIdx].id)) return;
            const dpx   = colX[phaseIdx] + CELL_PAD;
            const dpw   = colW[phaseIdx] - 2 * CELL_PAD;
            const lineX = dpx + dpw / 2;
            svg.appendChild(svgEl('line', {
                x1: lineX, y1: GROUP_HEADER_H + PHASE_HEADER_H,
                x2: lineX, y2: lanesBottom,
                stroke: '#DC2626', 'stroke-width': '1.5', 'stroke-dasharray': '4,3'
            }));
            const lt = svgEl('text', {
                x: lineX, y: lanesBottom + 18,
                'text-anchor': 'middle', 'font-size': '10', 'font-weight': '500',
                fill: '#DC2626', 'font-family': 'Salesforce Sans,Arial,sans-serif'
            });
            lt.textContent = trunc(task.name, Math.floor(dpw / 7));
            svg.appendChild(lt);
        });
    }

    _renderGantt(svg, wfv) {
        while (svg.firstChild) svg.removeChild(svg.firstChild);

        const wf    = wfv._wf;
        const tDays = wfv._maxDay + 5;
        const w     = wfv.ganttWidth;
        const h     = wfv.ganttHeight;

        const rf    = wfv._state.roleFilter;
        const tasks = flatTasks(wf)
            .filter(t => !t.isDeadline && (!rf || t.role === rf) && (wfv._state.showCompleted || !t.isComplete))
            .slice()
            .sort((a, b) => (a.dayOffset || 0) - (b.dayOffset || 0));

        // Header band
        svg.appendChild(svgEl('rect', { x: 0, y: 0, width: w, height: GANTT_HEADER_H, fill: '#f9fafb' }));

        // Legend
        const legend = [
            { label: 'Complete',      fill: '#9ca3af', stroke: '#6b7280', dash: null  },
            { label: 'Due date set',  fill: '#7A9B7E', stroke: '#5A7B5E', dash: null  },
            { label: 'No due date',   fill: '#e8f0e9', stroke: '#5A7B5E', dash: '6,3' }
        ];
        let legX = GANTT_LABEL_WIDTH + 12;
        legend.forEach(item => {
            const ba = { x: legX, y: 10, width: 24, height: 13, rx: 3,
                         fill: item.fill, stroke: item.stroke, 'stroke-width': '1.5' };
            if (item.dash) ba['stroke-dasharray'] = item.dash;
            svg.appendChild(svgEl('rect', ba));
            // checkmark on complete swatch
            if (!item.dash && item.fill === '#9ca3af') {
                const ck = svgEl('text', {
                    x: legX + 12, y: 21, 'text-anchor': 'middle',
                    'font-size': '9', fill: '#fff',
                    'font-family': 'Salesforce Sans,Arial,sans-serif'
                });
                ck.textContent = '✓';
                svg.appendChild(ck);
            }
            const lt = svgEl('text', {
                x: legX + 30, y: 21, 'font-size': '10', fill: '#6b7280',
                'font-family': 'Salesforce Sans,Arial,sans-serif'
            });
            lt.textContent = item.label;
            svg.appendChild(lt);
            legX += 100;
        });

        // Separator below header
        svg.appendChild(svgEl('line', {
            x1: 0, y1: GANTT_HEADER_H, x2: w, y2: GANTT_HEADER_H,
            stroke: '#e5e7eb', 'stroke-width': '1'
        }));

        // Day grid lines + labels
        for (let d = 0; d <= tDays; d += 10) {
            const x = GANTT_LABEL_WIDTH + d * GANTT_DAY_WIDTH;
            svg.appendChild(svgEl('line', {
                x1: x, y1: GANTT_HEADER_H, x2: x, y2: h,
                stroke: '#e5e7eb', 'stroke-width': '1'
            }));
            const t = svgEl('text', {
                x, y: GANTT_HEADER_H - 10,
                'text-anchor': 'middle', 'font-size': '10',
                fill: '#9ca3af', 'font-family': 'Salesforce Sans,Arial,sans-serif'
            });
            t.textContent = `Day ${d}`;
            svg.appendChild(t);
        }

        tasks.forEach((task, idx) => {
            const rowY  = GANTT_HEADER_H + idx * GANTT_ROW_HEIGHT;
            const c     = rc(task.role);
            const done  = task.isComplete;
            const voided = isVoided(task);
            const pend  = isPending(task);
            const midY  = rowY + GANTT_ROW_HEIGHT / 2;

            // Row background
            svg.appendChild(svgEl('rect', {
                x: 0, y: rowY, width: w, height: GANTT_ROW_HEIGHT,
                fill: voided ? '#1f2937' : (done ? '#f3f4f6' : (idx % 2 === 0 ? '#fafafa' : '#fff'))
            }));
            svg.appendChild(svgEl('line', {
                x1: 0, y1: rowY + GANTT_ROW_HEIGHT, x2: w, y2: rowY + GANTT_ROW_HEIGHT,
                stroke: '#e5e7eb', 'stroke-width': '0.5'
            }));

            // Status dot in label column
            const dotFill = voided ? '#4b5563' : (done ? '#9ca3af' : (pend ? c.border : c.bg));
            svg.appendChild(svgEl('circle', {
                cx: 10, cy: midY, r: 4, fill: dotFill
            }));

            // Task name label
            const maxLabelCh = Math.floor((GANTT_LABEL_WIDTH - 28) / 6.5);
            const lblAttrs   = {
                x: 20, y: midY + 4,
                'font-size': '11',
                fill: voided ? '#6b7280' : (done ? '#9ca3af' : '#374151'),
                'font-family': 'Salesforce Sans,Arial,sans-serif'
            };
            if (done || voided) lblAttrs['text-decoration'] = 'line-through';
            const lbl = svgEl('text', lblAttrs);
            lbl.textContent = trunc(task.name, maxLabelCh);
            svg.appendChild(lbl);

            // Bar
            const barX    = GANTT_LABEL_WIDTH + (task.dayOffset || 0) * GANTT_DAY_WIDTH;
            const barW    = Math.max((task.duration || 1) * GANTT_DAY_WIDTH, GANTT_MIN_BAR);
            const barY    = rowY + 8;
            const barH    = GANTT_ROW_HEIGHT - 16;
            const hasDDG  = !!task.dueDate;

            let barFill, barStroke, barDash, barTextFill;
            if (voided)    { barFill = '#374151'; barStroke = '#1f2937'; barTextFill = '#6b7280'; }
            else if (done) { barFill = '#9ca3af'; barStroke = '#6b7280'; barTextFill = '#fff'; }
            else if (!hasDDG) { barFill = c.bgLight; barStroke = c.border; barDash = '6,3'; barTextFill = c.text; }
            else           { barFill = c.bg;      barStroke = c.border; barTextFill = '#fff'; }

            const barAttrs = {
                x: barX, y: barY, width: barW, height: barH,
                rx: 6, fill: barFill, stroke: barStroke, 'stroke-width': '2'
            };
            if (barDash) barAttrs['stroke-dasharray'] = barDash;

            const g = svgEl('g', { style: 'cursor:pointer' });
            g.appendChild(svgEl('rect', barAttrs));

            // Checkmark badge on completed bars (not voided)
            const usedRightG = (done && !voided) ? 24 : 6;
            if (done && !voided) {
                g.appendChild(svgEl('circle', {
                    cx: barX + barW - 14, cy: barY + 14, r: 9,
                    fill: '#fff', opacity: '0.9'
                }));
                const ck = svgEl('text', {
                    x: barX + barW - 14, y: barY + 19,
                    'text-anchor': 'middle', 'font-size': '11', fill: '#6f7a7e',
                    'font-family': 'Salesforce Sans,Arial,sans-serif'
                });
                ck.textContent = '✓';
                g.appendChild(ck);
            }

            // Task name inside bar
            const maxBarCh = Math.max(Math.floor((barW - 12 - usedRightG) / 6.5), 0);
            if (maxBarCh > 2) {
                const nameInBarAttrs = {
                    x: barX + 8, y: barY + barH / 2 + 4,
                    'font-size': '11', 'font-weight': '600',
                    fill: barTextFill,
                    'font-family': 'Salesforce Sans,Arial,sans-serif'
                };
                if (voided) nameInBarAttrs['text-decoration'] = 'line-through';
                const nameInBar = svgEl('text', nameInBarAttrs);
                nameInBar.textContent = trunc(task.name, maxBarCh);
                g.appendChild(nameInBar);
            }

            const tsnap = { ...task };
            g.addEventListener('click',     ()  => this._openTask(tsnap.id));
            g.addEventListener('mouseover', (e) => this._showTip(e, tsnap));
            g.addEventListener('mouseout',  ()  => this._hideTip());
            svg.appendChild(g);
        });
    }

    // â”€â”€ Task panel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    _openTask(taskId) {
        const entry = this._taskIndex[taskId];
        if (!entry) return;
        const { task } = entry;
        const wf = this._rawBundle.workflows.find(w => w.id === entry.workflowId);
        const c  = rc(task.role);

        const incomingDeps = [];
        const outgoingDeps = [];
        if (wf) {
            (wf.dependencies || []).forEach(dep => {
                if (dep.toTaskId === taskId) {
                    const fe = this._taskIndex[dep.fromTaskId];
                    if (fe) incomingDeps.push({
                        key:       dep.id || dep.fromTaskId + dep.toTaskId,
                        taskName:  fe.task.name,
                        label:     dep.adjustDueDate ? 'Due-date based' : 'Completion-based',
                        cardClass: 'dep-card ' + (dep.adjustDueDate ? 'dep-card-duedate' : 'dep-card-completion')
                    });
                }
                if (dep.fromTaskId === taskId) {
                    const te = this._taskIndex[dep.toTaskId];
                    if (te) outgoingDeps.push({
                        key:      dep.id || dep.fromTaskId + dep.toTaskId,
                        taskName: te.task.name,
                        label:    dep.adjustDueDate ? 'Due-date based' : 'Completion-based'
                    });
                }
            });
        }

        const isClosed = task.isComplete || task.status === 'Not Applicable' || isVoided(task);
        this.selectedTask = {
            id:             task.id,
            name:           task.name,
            role:           displayRole(task.role),
            phaseName:      entry.phaseName,
            phaseId:        entry.phaseId,
            rolePillStyle:  `background:${c.bg};color:#fff;border:1.5px solid ${c.border};`,
            instructions:   task.instructions,
            dueDateLabel:   formatDate(task.dueDate),
            dueDate:        task.dueDate,
            ownerId:        task.ownerId,
            ownerName:      task.ownerName,
            estimatedHours: task.estimatedHours,
            showHours:      task.estimatedHours != null && task.estimatedHours > 0,
            isComplete:     task.isComplete,
            isClosed,
            hasIncoming:    incomingDeps.length > 0,
            hasOutgoing:    outgoingDeps.length > 0,
            incomingDeps,
            outgoingDeps
        };
        this.isEditingDueDate = false;
        this.isEditingOwner   = false;
    }

    // â”€â”€ Tooltip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    _showTip(event, task) {
        if (this._lastTipId === task.id) return;
        this._lastTipId = task.id;
        const root     = this.template.querySelector('.task-tracker-root');
        const rootRect = root ? root.getBoundingClientRect() : { left: 0, top: 0 };
        const r        = event.currentTarget.getBoundingClientRect();
        const left     = r.left - rootRect.left + r.width / 2;
        const top      = r.top  - rootRect.top;
        this._tooltipOnly = true;
        this.hoverTooltip = {
            name:      task.name,
            showHours: task.estimatedHours > 0,
            hours:     task.estimatedHours,
            style:     `left:${left}px;top:${top}px;`
        };
    }

    _hideTip() {
        if (!this._lastTipId) return;
        this._lastTipId   = null;
        this._tooltipOnly = true;
        this.hoverTooltip = null;
    }

    // â”€â”€ Event handlers â€” accordion + view controls â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    handleToggleWorkflow(event) {
        const id = event.currentTarget.dataset.id;
        if (this._wfState[id]) this._wfState[id].isOpen = !this._wfState[id].isOpen;
        this._rebuild();
    }

    handleSwitchView(event) {
        const { workflow, view } = event.currentTarget.dataset;
        if (this._wfState[workflow]) this._wfState[workflow].activeView = view;
        this._rebuild();
    }

    handleRoleFilter(event) {
        const { workflow, role } = event.currentTarget.dataset;
        if (this._wfState[workflow]) this._wfState[workflow].roleFilter = role;
        this._rebuild();
    }

    handleClearRoleFilter(event) {
        const { workflow } = event.currentTarget.dataset;
        if (this._wfState[workflow]) this._wfState[workflow].roleFilter = null;
        this._rebuild();
    }

    handleToggleCompleted(event) {
        const { workflow } = event.currentTarget.dataset;
        const st = this._wfState[workflow];
        if (st) st.showCompleted = !st.showCompleted;
        this._rebuild();
    }

    handleMyTasksRole(event) {
        const { workflow, role } = event.currentTarget.dataset;
        if (this._wfState[workflow]) this._wfState[workflow].myTasksRole = role || null;
        this._rebuild();
    }

    _togglePhase(wfId, phaseId) {
        const st = this._wfState[wfId];
        if (!st) return;
        if (!st.collapsedPhases) st.collapsedPhases = new Set();
        if (st.collapsedPhases.has(phaseId)) {
            st.collapsedPhases.delete(phaseId);
        } else {
            st.collapsedPhases.add(phaseId);
        }
        this._rebuild();
    }

    // â”€â”€ Event handlers â€” task panel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    handleOpenTask(event) {
        this._openTask(event.currentTarget.dataset.id);
    }

    handleClosePanel() {
        this.selectedTask     = null;
        this.isEditingDueDate = false;
        this.isEditingOwner   = false;
        this.pendingDueDate   = null;
        this.pendingOwnerId   = null;
    }

    handleEditDueDateClick() { this.isEditingDueDate = true; this.pendingDueDate = null; }
    handleCancelDueDate()    { this.isEditingDueDate = false; this.pendingDueDate = null; }

    handleEditOwnerClick() {
        this.isEditingOwner = true;
        this.pendingOwnerId = null;
    }

    handleCancelOwner() {
        this.isEditingOwner = false;
        this.pendingOwnerId = null;
    }

    handleOwnerPickerChange(event) {
        this.pendingOwnerId = event.detail.recordId || null;
    }

    get isSaveOwnerDisabled() { return !this.pendingOwnerId; }

    handleSaveOwner() {
        if (!this.pendingOwnerId) return;
        const panelId = this.selectedTask.id;
        updateTaskOwner({ taskId: panelId, ownerId: this.pendingOwnerId })
            .then(() => {
                this.isEditingOwner = false;
                this.pendingOwnerId = null;
                this.dispatchEvent(new ShowToastEvent({ title: 'Owner updated', variant: 'success' }));
                return refreshApex(this._wiredResult).then(() => this._openTask(panelId));
            })
            .catch(err => {
                const msg = err.body && err.body.message ? err.body.message : 'Could not update owner.';
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
            });
    }

    handleDueDateChange(event) {
        this.pendingDueDate = event.target.value || null;
    }

    get isSaveDueDateDisabled() { return this.pendingDueDate === null; }

    handleSaveDueDate() {
        if (!this.selectedTask) return;
        const panelId = this.selectedTask.id;
        updateTaskDueDate({ taskId: panelId, dueDate: this.pendingDueDate })
            .then(() => {
                this.isEditingDueDate = false;
                this.pendingDueDate   = null;
                this.dispatchEvent(new ShowToastEvent({ title: 'Due date updated', variant: 'success' }));
                return refreshApex(this._wiredResult).then(() => this._openTask(panelId));
            })
            .catch(err => {
                const msg = err.body && err.body.message ? err.body.message : 'Could not update due date.';
                this.dispatchEvent(new ShowToastEvent({ title: 'Error saving', message: msg, variant: 'error' }));
            });
    }

    handleReopenTask() {
        if (!this.selectedTask) return;
        const panelId = this.selectedTask.id;
        reopenTask({ taskId: panelId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Task reopened', variant: 'success' }));
                return refreshApex(this._wiredResult).then(() => this._openTask(panelId));
            })
            .catch(err => {
                const msg = err.body && err.body.message ? err.body.message : 'Could not reopen task.';
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
            });
    }

    handleNavigateToTask() {
        if (!this.selectedTask) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.selectedTask.id, objectApiName: 'Task', actionName: 'view' }
        });
    }

    handleNavigateToCase() {
        if (!this.selectedTask || !this.selectedTask.phaseId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.selectedTask.phaseId, objectApiName: 'Case', actionName: 'view' }
        });
    }

    // â”€â”€ Event handlers â€” task completion â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    handleMarkComplete() {
        this._saveCompletion('Completed');
    }

    handleMarkNotApplicable() {
        this._saveCompletion('Not Applicable');
    }

    _saveCompletion(status) {
        if (!this.selectedTask) return;
        const taskId = this.selectedTask.id;
        completeTask({ taskId, status })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title:   `Task marked as ${status}`,
                    variant: 'success'
                }));
                this.selectedTask = null;
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                const msg = err.body && err.body.message ? err.body.message : 'Could not update task.';
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
            });
    }
}