import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getWorkflowsForMatter from '@salesforce/apex/MatterTaskTrackerV2Controller.getWorkflowsForMatter';
import completeTask from '@salesforce/apex/MatterTaskTrackerV2Controller.completeTask';
import reopenTask from '@salesforce/apex/MatterTaskTrackerV2Controller.reopenTask';
import updateTaskDueDate from '@salesforce/apex/MatterTaskTrackerV2Controller.updateTaskDueDate';

// ── Swimlane layout constants ─────────────────────────────────────────────────
const LANE_LABEL_WIDTH    = 230;   // role label column width
const LANE_PAD            = 10;    // top/bottom padding inside a lane
const LANE_MIN_H          = 72;    // minimum lane height
const PHASE_COL_W         = 220;   // expanded phase column width
const PHASE_COL_COLLAPSED = 36;    // collapsed phase column width
const CELL_PAD            = 8;     // padding inside a phase×role cell
const CELL_TASK_H         = 46;    // task card height
const CELL_TASK_GAP       = 6;     // vertical gap between task cards
const GROUP_HEADER_H      = 24;    // parent-phase group label band height
const PHASE_HEADER_H      = 38;    // phase column header band height
const DEADLINE_LABEL_H    = 28;    // space below lanes for deadline labels

// ── Gantt layout constants ────────────────────────────────────────────────────
const GANTT_HEADER_H      = 68;
const GANTT_ROW_HEIGHT    = 36;
const GANTT_LABEL_WIDTH   = 240;
const GANTT_DAY_WIDTH     = 24;
const GANTT_MIN_BAR       = 44;

// ── Timeline layout constants ─────────────────────────────────────────────────
const TL_LABEL_W     = 200;
const TL_LEGEND_H    = 38;
const TL_HEADER_H    = 38;
const TL_DAY_W       = 34;
const TL_TASK_H      = 42;
const TL_TASK_GAP    = 6;
const TL_ROW_PAD     = 10;
const TL_MIN_TASK_W  = 84;

// ── Color palettes ────────────────────────────────────────────────────────────
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
    { id: 'timeline', label: 'Timeline'       },
    { id: 'swimlane', label: 'Swimlane'       },
    { id: 'gantt',    label: 'Gantt'          },
    { id: 'mytasks',  label: 'My Tasks'       },
    { id: 'summary',  label: 'Status Summary' }
];

const COMPLETION_OPTIONS = [
    { label: 'Completed',       value: 'Completed'       },
    { label: 'Not Applicable',  value: 'Not Applicable'  }
];

// Canonical role row order — roles not listed here fall back to alphabetical
const ROLE_ORDER = ['Attorney', 'Paralegal', 'CSS', 'Client'];

// ── Pure helpers ──────────────────────────────────────────────────────────────
const PENDING_STATUS = 'Waiting On Other Tasks';

function rc(role) {
    return ROLE_COLORS[role] || DEFAULT_COLORS;
}

function isPending(task) {
    return !task.isComplete && task.status === PENDING_STATUS;
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

// Greedy interval scheduling: returns number of tracks needed to stack tasks without overlap.
function countTracks(tasks) {
    if (!tasks.length) return 1;
    const sorted = tasks.slice().sort((a, b) => (a.dayOffset || 0) - (b.dayOffset || 0));
    const trackEnds = [];
    for (const t of sorted) {
        const start   = t.dayOffset || 0;
        const dispEnd = start + Math.max(t.duration || 1, TL_MIN_TASK_W / TL_DAY_W);
        let placed = false;
        for (let i = 0; i < trackEnds.length; i++) {
            if (trackEnds[i] <= start) { trackEnds[i] = dispEnd; placed = true; break; }
        }
        if (!placed) trackEnds.push(dispEnd);
    }
    return trackEnds.length || 1;
}

// ── Component ─────────────────────────────────────────────────────────────────
export default class MatterTaskTrackerV2 extends NavigationMixin(LightningElement) {
    @api recordId;

    @track workflowViews       = [];
    @track isLoading           = true;
    @track isEmpty             = false;
    @track error;
    @track selectedTask;
    @track isEditingDueDate    = false;
    @track showCompletionModal = false;
    @track completionTaskName;
    @track completionStatus;
    @track hoverTooltip;

    _wiredResult;
    _rawBundle;
    _wfState     = {};
    _taskIndex   = {};
    _completionId;
    _tooltipOnly = false;
    _lastTipId;

    get completionOptions() { return COMPLETION_OPTIONS; }
    get isSaveDisabled()    { return !this.completionStatus; }

    // ── Wire ──────────────────────────────────────────────────────────────────
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

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    renderedCallback() {
        if (this._tooltipOnly) {
            this._tooltipOnly = false;
            return;
        }
        this._renderAllSvgs();
    }

    // ── Build view model ──────────────────────────────────────────────────────
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

        bundle.workflows.forEach((wf, idx) => {
            if (!this._wfState[wf.id]) {
                this._wfState[wf.id] = {
                    isOpen:          idx === 0,
                    activeView:      'swimlane',
                    roleFilter:      null,
                    showDeps:        true,
                    showCompleted:   true,
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

        // Compute sorted + leaf phases once — reused for swimlane layout and phase summaries.
        const wfIdStr    = String(wf.id || '');
        const sorted     = this._sortPhases(wf.phases || [], wf.id);
        const leafPhases = this._getLeafPhases(sorted, wfIdStr);
        const colW       = leafPhases.map(p =>
            st.collapsedPhases && st.collapsedPhases.has(p.id) ? PHASE_COL_COLLAPSED : PHASE_COL_W
        );
        const chartW = Math.max(LANE_LABEL_WIDTH + colW.reduce((a, b) => a + b, 0), 700);
        const chartH = this._computeChartH_matrix(wf, roles, st);

        // Gantt: day-timeline (height accounts for role filter)
        const ganttTasks = st.roleFilter ? nonDead.filter(t => t.role === st.roleFilter) : nonDead;
        const ganttW = Math.max(GANTT_LABEL_WIDTH + tDays * GANTT_DAY_WIDTH, 700);
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
                label:      role,
                dotStyle:   `background:${c.bg};`,
                fillStyle:  `width:${rp}%;background:${c.bg};`,
                countLabel: `${rcd} / ${rt.length}`
            };
        });

        // By-phase breakdown (leaf phases only — those with tasks)
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
                label:     role,
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
        const isTimeline = st.activeView === 'timeline';

        // Timeline dimensions
        const tlTasks = nonDead.filter(
            t => (!st.roleFilter || t.role === st.roleFilter) && (st.showCompleted || !t.isComplete)
        );
        const tlRoleH = roles.map(role => {
            const tracks = countTracks(tlTasks.filter(t => t.role === role));
            return TL_ROW_PAD * 2 + Math.max(tracks, 1) * (TL_TASK_H + TL_TASK_GAP);
        });
        const timelineW = Math.max(TL_LABEL_W + (maxDay + 5) * TL_DAY_W, 700);
        const timelineH = TL_LEGEND_H + TL_HEADER_H + tlRoleH.reduce((a, b) => a + b, 0) + 10;

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
            isTimeline,
            isMyTasks:       st.activeView === 'mytasks',
            isSummary:       st.activeView === 'summary',
            showControlsRow: isSwimlane || isGantt || isTimeline,
            showDepsBtn:     isSwimlane || isTimeline,
            timelineWidth:   timelineW,
            timelineHeight:  timelineH,
            myTasksAllTabClass: 'mytasks-tab' + (!st.myTasksRole ? ' mytasks-tab-active' : ''),
            allPillClass:   'role-pill-all role-pill' + (!st.roleFilter ? ' role-pill-active' : ''),
            rolePills,
            depsBtnClass:      'deps-btn' + (st.showDeps ? ' deps-btn-on' : ''),
            showDeps:          st.showDeps,
            showCompleted:     st.showCompleted,
            completedBtnClass: 'deps-btn' + (st.showCompleted ? ' deps-btn-on' : ''),
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
            // orphan safety net — use id comparison, not reference equality
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

    // ── SVG rendering ─────────────────────────────────────────────────────────
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
            if (wfv.isTimeline) {
                const el = this.template.querySelector(`[data-timeline-id="${wfv.id}"]`);
                if (el) this._renderTimeline(el, wfv);
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
        const groupColorMap = {}; // parentId → color index
        const phaseColorIdx = {}; // phaseId  → color index
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

        // ── Pass 1: task positions (for dep arrows) ───────────────────────
        const taskPos = {};
        leafPhases.forEach((phase, pi) => {
            if (colW[pi] === PHASE_COL_COLLAPSED) return;
            const tw = colW[pi] - 2 * CELL_PAD;
            roles.forEach((role, ri) => {
                phAll(phase)
                    .filter(t => !t.isDeadline && t.role === role && visSet.has(t.id))
                    .forEach((task, ti) => {
                        const tx = colX[pi] + CELL_PAD;
                        const ty = laneY[ri] + LANE_PAD + ti * (CELL_TASK_H + CELL_TASK_GAP);
                        taskPos[task.id] = { lx: tx, rx: tx + tw, my: ty + CELL_TASK_H / 2 };
                    });
            });
        });

        // ── Lane stripe backgrounds + role pills ──────────────────────────
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
            pt.textContent = trunc(role, Math.floor((pillW - 16) / 7.5));
            svg.appendChild(pt);
        });

        // ── Group header band (top strip) ─────────────────────────────────
        // Light neutral background across the whole group-header area
        svg.appendChild(svgEl('rect', {
            x: LANE_LABEL_WIDTH, y: 0,
            width: totalW - LANE_LABEL_WIDTH, height: GROUP_HEADER_H,
            fill: '#f0f2f5'
        }));

        // Build group spans: parentPhaseId → { x, w, name, colorIdx }
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

        // ── Phase column backgrounds + headers (leaf phases) ──────────────
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
                bt.textContent = '−';
                btn.appendChild(bt);
                btn.addEventListener('click', () => this._togglePhase(wfIdL, phId));
                svg.appendChild(btn);
            }
        });

        // ── Dependency curves (behind task cards) ─────────────────────────
        if (st.showDeps) this._renderDepsMatrix(svg, wf, taskPos);

        // ── Task cards ────────────────────────────────────────────────────
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
                    const pend     = isPending(task);
                    const hasDueDate = !!task.dueDate;   // ActivityDate set

                    let fill, stroke, textFill;
                    if (done) {
                        fill = '#8f989c'; stroke = '#6f7a7e'; textFill = '#fff';
                    } else if (pend || !hasDueDate) {
                        // pending OR no due date set → light tint
                        fill = c2.bgLight; stroke = c2.border; textFill = c2.text;
                    } else {
                        fill = c2.bg; stroke = c2.border; textFill = '#fff';
                    }

                    const g = svgEl('g', { style: 'cursor:pointer' });
                    const cardAttrs = { x: tx, y: ty, width: tw, height: th, rx: 6, fill, stroke, 'stroke-width': '2' };
                    if (!hasDueDate && !done) cardAttrs['stroke-dasharray'] = '6,3';
                    g.appendChild(svgEl('rect', cardAttrs));
                    if (done) {
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
                    const usedRight = done ? 26 : 8;
                    const maxCh2    = Math.max(Math.floor((tw - 10 - usedRight) / 6.5), 5);
                    const hasDue    = task.hasScheduledDate;   // WIP_Est_Due_Date__c or ActivityDate is set
                    const nameY     = hasDue ? ty + th / 2 - 4 : ty + th / 2 + 5;
                    const nameEl    = svgEl('text', {
                        x: tx + 8, y: nameY,
                        'font-size': '11', 'font-weight': '600',
                        fill: textFill, opacity: pend ? '0.8' : '1',
                        'font-family': 'Salesforce Sans,Arial,sans-serif'
                    });
                    nameEl.textContent = trunc(task.name, maxCh2);
                    g.appendChild(nameEl);
                    if (hasDue) {
                        const dayEl = svgEl('text', {
                            x: tx + 8, y: ty + th / 2 + 12,
                            'font-size': '9', fill: textFill, opacity: '0.72',
                            'font-family': 'Salesforce Sans,Arial,sans-serif'
                        });
                        dayEl.textContent = `Day ${task.dayOffset}`;
                        g.appendChild(dayEl);
                    }
                    const tid   = task.id;
                    const tsnap = { ...task };
                    g.addEventListener('click',     ()  => this._openTask(tid));
                    g.addEventListener('mouseover', (e) => this._showTip(e, tsnap));
                    g.addEventListener('mouseout',  ()  => this._hideTip());
                    svg.appendChild(g);
                });
            });
        });

        // ── Deadline markers ──────────────────────────────────────────────
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

    _renderDepsMatrix(svg, wf, taskPos) {
        (wf.dependencies || []).forEach(dep => {
            const from = taskPos[dep.fromTaskId];
            const to   = taskPos[dep.toTaskId];
            if (!from || !to) return;

            const stroke = dep.adjustDueDate ? '#C07058' : '#16a34a';
            const dash   = dep.adjustDueDate ? '5,3' : null;

            const fx  = from.rx;
            const fy  = from.my;
            const tx  = to.lx;
            const ty  = to.my;
            const cpX = (fx + tx) / 2;

            const pathAttrs = {
                d: `M ${fx} ${fy} C ${cpX} ${fy} ${cpX} ${ty} ${tx} ${ty}`,
                stroke, 'stroke-width': '1.5', fill: 'none', opacity: '0.75'
            };
            if (dash) pathAttrs['stroke-dasharray'] = dash;
            const pathEl = svgEl('path', pathAttrs);
            svg.appendChild(pathEl);

            // Arrowhead at true arc-length midpoint using SVG path measurement.
            // getPointAtLength gives the visual halfway point regardless of bezier parameterization.
            const totalLen = pathEl.getTotalLength();
            const midPt    = pathEl.getPointAtLength(totalLen / 2);
            const prevPt   = pathEl.getPointAtLength(Math.max(0, totalLen / 2 - 2));

            const tdx = midPt.x - prevPt.x;
            const tdy = midPt.y - prevPt.y;
            const len = Math.sqrt(tdx * tdx + tdy * tdy) || 1;
            const nx  = tdx / len;
            const ny  = tdy / len;
            const px  = -ny;
            const py  =  nx;

            const tipX  = midPt.x;
            const tipY  = midPt.y;
            const baseX = midPt.x - nx * 10;
            const baseY = midPt.y - ny * 10;
            const pts = [
                `${tipX},${tipY}`,
                `${baseX - px * 5},${baseY - py * 5}`,
                `${baseX + px * 5},${baseY + py * 5}`
            ].join(' ');

            svg.appendChild(svgEl('polygon', {
                points: pts, fill: stroke, opacity: '0.9'
            }));
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
            .filter(t => !t.isDeadline && (!rf || t.role === rf))
            .slice()
            .sort((a, b) => (a.dayOffset || 0) - (b.dayOffset || 0));

        // Header band
        svg.appendChild(svgEl('rect', { x: 0, y: 0, width: w, height: GANTT_HEADER_H, fill: '#f9fafb' }));

        // Legend
        const legend = [
            { label: 'Complete',    fill: '#9ca3af', stroke: '#6b7280', dash: null },
            { label: 'In Progress', fill: '#7A9B7E', stroke: '#5A7B5E', dash: null },
            { label: 'Waiting',     fill: '#e8f0e9', stroke: '#5A7B5E', dash: '4,3' }
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
        for (let d = 0; d <= tDays; d += 5) {
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
            const pend  = isPending(task);
            const midY  = rowY + GANTT_ROW_HEIGHT / 2;

            // Row background — completed rows get a distinct light grey tint
            svg.appendChild(svgEl('rect', {
                x: 0, y: rowY, width: w, height: GANTT_ROW_HEIGHT,
                fill: done ? '#f3f4f6' : (idx % 2 === 0 ? '#fafafa' : '#fff')
            }));
            svg.appendChild(svgEl('line', {
                x1: 0, y1: rowY + GANTT_ROW_HEIGHT, x2: w, y2: rowY + GANTT_ROW_HEIGHT,
                stroke: '#e5e7eb', 'stroke-width': '0.5'
            }));

            // Status dot in label column
            const dotFill = done ? '#9ca3af' : (pend ? c.border : c.bg);
            svg.appendChild(svgEl('circle', {
                cx: 10, cy: midY, r: 4, fill: dotFill
            }));

            // Task name label
            const maxLabelCh = Math.floor((GANTT_LABEL_WIDTH - 28) / 6.5);
            const lblAttrs   = {
                x: 20, y: midY + 4,
                'font-size': '11',
                fill: done ? '#9ca3af' : '#374151',
                'font-family': 'Salesforce Sans,Arial,sans-serif'
            };
            if (done) lblAttrs['text-decoration'] = 'line-through';
            const lbl = svgEl('text', lblAttrs);
            lbl.textContent = trunc(task.name, maxLabelCh);
            svg.appendChild(lbl);

            // Bar
            const barX = GANTT_LABEL_WIDTH + (task.dayOffset || 0) * GANTT_DAY_WIDTH;
            const barW = Math.max((task.duration || 1) * GANTT_DAY_WIDTH, GANTT_MIN_BAR);
            const barY = rowY + 5;
            const barH = GANTT_ROW_HEIGHT - 10;

            let barFill, barStroke, barDash;
            if (done)      { barFill = '#9ca3af'; barStroke = '#6b7280'; }
            else if (pend) { barFill = c.bgLight; barStroke = c.border; barDash = '4,3'; }
            else           { barFill = c.bg;      barStroke = c.border; }

            const barAttrs = {
                x: barX, y: barY, width: barW, height: barH,
                rx: 4, fill: barFill, stroke: barStroke, 'stroke-width': '1.5'
            };
            if (barDash) barAttrs['stroke-dasharray'] = barDash;

            const g = svgEl('g', { style: 'cursor:pointer' });
            g.appendChild(svgEl('rect', barAttrs));

            // Checkmark badge on completed bars
            if (done) {
                g.appendChild(svgEl('circle', {
                    cx: barX + barW - 12, cy: barY + barH / 2, r: 8,
                    fill: '#6b7280'
                }));
                const ck = svgEl('text', {
                    x: barX + barW - 12, y: barY + barH / 2 + 4,
                    'text-anchor': 'middle', 'font-size': '10', fill: '#fff',
                    'font-family': 'Salesforce Sans,Arial,sans-serif'
                });
                ck.textContent = '✓';
                g.appendChild(ck);
            }

            const tsnap = { ...task };
            g.addEventListener('click',     ()  => this._openTask(tsnap.id));
            g.addEventListener('mouseover', (e) => this._showTip(e, tsnap));
            g.addEventListener('mouseout',  ()  => this._hideTip());
            svg.appendChild(g);
        });
    }

    // ── Timeline rendering ────────────────────────────────────────────────────
    _renderTimeline(svg, wfv) {
        while (svg.firstChild) svg.removeChild(svg.firstChild);

        const wf    = wfv._wf;
        const st    = wfv._state;
        const roles = wfv._roles;
        const tDays = wfv._maxDay + 5;
        const rf    = st.roleFilter;

        const allTasks = flatTasks(wf).filter(
            t => !t.isDeadline &&
                 (!rf || t.role === rf) &&
                 (st.showCompleted || !t.isComplete)
        );

        // Row heights (greedy track-stacking per role)
        const rowH = roles.map(role => {
            const tracks = countTracks(allTasks.filter(t => t.role === role));
            return TL_ROW_PAD * 2 + Math.max(tracks, 1) * (TL_TASK_H + TL_TASK_GAP);
        });
        const rowY = [];
        let cy = TL_LEGEND_H + TL_HEADER_H;
        roles.forEach((_, ri) => { rowY.push(cy); cy += rowH[ri]; });

        const totalW = Math.max(TL_LABEL_W + tDays * TL_DAY_W, 700);
        const totalH = cy + 10;
        svg.setAttribute('width',  totalW);
        svg.setAttribute('height', totalH);

        // ── Legend strip ──────────────────────────────────────────
        svg.appendChild(svgEl('rect', { x: 0, y: 0, width: totalW, height: TL_LEGEND_H, fill: '#f9fafb' }));
        svg.appendChild(svgEl('line', { x1: 0, y1: TL_LEGEND_H, x2: totalW, y2: TL_LEGEND_H, stroke: '#e5e7eb', 'stroke-width': '1' }));

        const drawLegLine = (lx, color, dash, label) => {
            const ly  = TL_LEGEND_H / 2;
            const la  = { x1: lx, y1: ly, x2: lx + 30, y2: ly, stroke: color, 'stroke-width': '2' };
            if (dash) la['stroke-dasharray'] = dash;
            svg.appendChild(svgEl('line', la));
            svg.appendChild(svgEl('polygon', {
                points: `${lx + 24},${ly - 4} ${lx + 30},${ly} ${lx + 24},${ly + 4}`,
                fill: color
            }));
            const lt = svgEl('text', { x: lx + 36, y: ly + 4, 'font-size': '11', fill: '#6b7280', 'font-family': 'Salesforce Sans,Arial,sans-serif' });
            lt.textContent = label;
            svg.appendChild(lt);
        };
        drawLegLine(TL_LABEL_W + 8,   '#DC2626', '5,3', 'Completion-based');
        drawLegLine(TL_LABEL_W + 190, '#16a34a', null,  'Due-date-based');

        // ── Day axis header ───────────────────────────────────────
        svg.appendChild(svgEl('rect', { x: 0, y: TL_LEGEND_H, width: totalW, height: TL_HEADER_H, fill: '#f3f4f6' }));
        svg.appendChild(svgEl('line', { x1: TL_LABEL_W, y1: TL_LEGEND_H, x2: TL_LABEL_W, y2: totalH, stroke: '#d1d5db', 'stroke-width': '1' }));
        svg.appendChild(svgEl('line', { x1: 0, y1: TL_LEGEND_H + TL_HEADER_H, x2: totalW, y2: TL_LEGEND_H + TL_HEADER_H, stroke: '#e5e7eb', 'stroke-width': '1' }));

        for (let d = 0; d <= tDays; d += 5) {
            const x = TL_LABEL_W + d * TL_DAY_W;
            svg.appendChild(svgEl('line', { x1: x, y1: TL_LEGEND_H, x2: x, y2: totalH, stroke: '#e5e7eb', 'stroke-width': '1' }));
            const dlbl = svgEl('text', {
                x: x + 4, y: TL_LEGEND_H + TL_HEADER_H / 2 + 5,
                'font-size': '11', 'font-weight': '600', fill: '#6b7280',
                'font-family': 'Salesforce Sans,Arial,sans-serif'
            });
            dlbl.textContent = `Day ${d}`;
            svg.appendChild(dlbl);
        }

        // ── Pass 1: compute task positions + draw role rows ───────
        const taskPos  = {};
        const taskDraw = [];  // drawn after dep arrows

        roles.forEach((role, ri) => {
            const ry = rowY[ri];
            const rh = rowH[ri];
            const c  = rc(role);

            svg.appendChild(svgEl('rect', { x: 0, y: ry, width: totalW, height: rh, fill: ri % 2 === 0 ? '#f9fafb' : '#fff' }));
            svg.appendChild(svgEl('line', { x1: 0, y1: ry, x2: totalW, y2: ry, stroke: '#e5e7eb', 'stroke-width': '0.5' }));

            // Role label pill
            const pillW = TL_LABEL_W - 20;
            const pillH = Math.min(44, rh - 12);
            const pillY = ry + (rh - pillH) / 2;
            svg.appendChild(svgEl('rect', { x: 10, y: pillY, width: pillW, height: pillH, rx: 8, fill: c.bg, stroke: c.border, 'stroke-width': '1.5' }));
            const pt = svgEl('text', {
                x: TL_LABEL_W / 2, y: pillY + pillH / 2 + 5,
                'text-anchor': 'middle', 'font-size': '12', 'font-weight': '600',
                fill: '#fff', 'font-family': 'Salesforce Sans,Arial,sans-serif'
            });
            pt.textContent = trunc(role, Math.floor((pillW - 16) / 7.2));
            svg.appendChild(pt);

            // Assign tasks to tracks (greedy)
            const rTasks    = allTasks.filter(t => t.role === role).slice().sort((a, b) => (a.dayOffset || 0) - (b.dayOffset || 0));
            const trackEnds = [];
            rTasks.forEach(task => {
                const start   = task.dayOffset || 0;
                const dispW   = Math.max((task.duration || 1) * TL_DAY_W, TL_MIN_TASK_W);
                const dispEnd = start + dispW / TL_DAY_W;
                let track = -1;
                for (let ti = 0; ti < trackEnds.length; ti++) {
                    if (trackEnds[ti] <= start) { track = ti; trackEnds[ti] = dispEnd; break; }
                }
                if (track === -1) { track = trackEnds.length; trackEnds.push(dispEnd); }

                const tx = TL_LABEL_W + start * TL_DAY_W;
                const ty = ry + TL_ROW_PAD + track * (TL_TASK_H + TL_TASK_GAP);
                const tw = dispW;
                const th = TL_TASK_H;

                taskPos[task.id] = { lx: tx, rx: tx + tw, my: ty + th / 2 };
                taskDraw.push({ task, tx, ty, tw, th });
            });
        });

        // ── Pass 2: dependency arrows (behind task cards) ─────────
        if (st.showDeps) {
            (wf.dependencies || []).forEach(dep => {
                const from = taskPos[dep.fromTaskId];
                const to   = taskPos[dep.toTaskId];
                if (!from || !to) return;

                const isDue  = dep.adjustDueDate;
                const stroke = isDue ? '#16a34a' : '#DC2626';
                const fx = from.rx; const fy = from.my;
                const tx = to.lx;   const ty = to.my;
                const cpX = (fx + tx) / 2;

                const pa = { d: `M ${fx} ${fy} C ${cpX} ${fy} ${cpX} ${ty} ${tx} ${ty}`, stroke, 'stroke-width': '1.5', fill: 'none', opacity: '0.75' };
                if (!isDue) pa['stroke-dasharray'] = '5,3';
                const pathEl = svgEl('path', pa);
                svg.appendChild(pathEl);

                const totalLen = pathEl.getTotalLength();
                const midPt    = pathEl.getPointAtLength(totalLen / 2);
                const prevPt   = pathEl.getPointAtLength(Math.max(0, totalLen / 2 - 2));
                const adx = midPt.x - prevPt.x;
                const ady = midPt.y - prevPt.y;
                const alen = Math.sqrt(adx * adx + ady * ady) || 1;
                const anx = adx / alen;  const any = ady / alen;
                const apx = -any;        const apy =  anx;
                const bx = midPt.x - anx * 10;  const by = midPt.y - any * 10;
                svg.appendChild(svgEl('polygon', {
                    points: `${midPt.x},${midPt.y} ${bx - apx * 5},${by - apy * 5} ${bx + apx * 5},${by + apy * 5}`,
                    fill: stroke, opacity: '0.9'
                }));
            });
        }

        // ── Pass 3: task cards (on top of arrows) ─────────────────
        taskDraw.forEach(({ task, tx, ty, tw, th }) => {
            const c2    = rc(task.role);
            const done  = task.isComplete;
            const pend  = isPending(task);
            const hasDD = !!task.dueDate;

            let fill, stroke, textFill;
            if (done) {
                fill = '#8f989c'; stroke = '#6f7a7e'; textFill = '#fff';
            } else if (pend || !hasDD) {
                fill = c2.bgLight; stroke = c2.border; textFill = c2.text;
            } else {
                fill = c2.bg; stroke = c2.border; textFill = '#fff';
            }

            const g  = svgEl('g', { style: 'cursor:pointer' });
            const ca = { x: tx, y: ty, width: tw, height: th, rx: 6, fill, stroke, 'stroke-width': '2' };
            if (!hasDD && !done) ca['stroke-dasharray'] = '6,3';
            g.appendChild(svgEl('rect', ca));

            if (done) {
                g.appendChild(svgEl('circle', { cx: tx + tw - 12, cy: ty + 12, r: 9, fill: '#fff', opacity: '0.9' }));
                const ck = svgEl('text', { x: tx + tw - 12, y: ty + 17, 'text-anchor': 'middle', 'font-size': '11', fill: '#6f7a7e', 'font-family': 'Salesforce Sans,Arial,sans-serif' });
                ck.textContent = '✓';
                g.appendChild(ck);
            }

            const usedR  = done ? 26 : 6;
            const maxCh  = Math.max(Math.floor((tw - 14 - usedR) / 6.5), 4);
            const showDay = task.hasScheduledDate;
            const nameEl = svgEl('text', {
                x: tx + 8, y: ty + th / 2 + (showDay ? -3 : 5),
                'font-size': '11', 'font-weight': '600',
                fill: textFill, opacity: pend ? '0.8' : '1',
                'font-family': 'Salesforce Sans,Arial,sans-serif'
            });
            nameEl.textContent = trunc(task.name, maxCh);
            g.appendChild(nameEl);

            if (showDay) {
                const dayEl = svgEl('text', { x: tx + 8, y: ty + th / 2 + 11, 'font-size': '9', fill: textFill, opacity: '0.72', 'font-family': 'Salesforce Sans,Arial,sans-serif' });
                dayEl.textContent = `Day ${task.dayOffset}`;
                g.appendChild(dayEl);
            }

            const tid   = task.id;
            const tsnap = { ...task };
            g.addEventListener('click',     ()  => this._openTask(tid));
            g.addEventListener('mouseover', (e) => this._showTip(e, tsnap));
            g.addEventListener('mouseout',  ()  => this._hideTip());
            svg.appendChild(g);
        });
    }

    // ── Task panel ────────────────────────────────────────────────────────────
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
                    if (fe) {
                        incomingDeps.push({
                            key:       dep.id || dep.fromTaskId + dep.toTaskId,
                            taskName:  fe.task.name,
                            label:     dep.adjustDueDate
                                ? `Due-date offset: ${dep.durationInDays} day(s)`
                                : `Triggered by completion + ${dep.durationInDays} day(s)`,
                            cardClass: 'dep-card ' + (dep.adjustDueDate ? 'dep-card-duedate' : 'dep-card-completion')
                        });
                    }
                }
                if (dep.fromTaskId === taskId) {
                    const te = this._taskIndex[dep.toTaskId];
                    if (te) {
                        outgoingDeps.push({
                            key:      dep.id || dep.fromTaskId + dep.toTaskId,
                            taskName: te.task.name,
                            label:    dep.adjustDueDate
                                ? `Sets due-date offset: ${dep.durationInDays} day(s)`
                                : `Triggers after completion + ${dep.durationInDays} day(s)`
                        });
                    }
                }
            });
        }

        const isClosed = task.isComplete || task.status === 'Not Applicable';
        this.selectedTask = {
            id:             task.id,
            name:           task.name,
            role:           task.role,
            phaseName:      entry.phaseName,
            phaseId:        entry.phaseId,
            rolePillStyle:  `background:${c.bg};color:#fff;border:1.5px solid ${c.border};`,
            instructions:   task.instructions,
            dueDateLabel:   formatDate(task.dueDate),
            dueDate:        task.dueDate,
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
    }

    // ── Tooltip ───────────────────────────────────────────────────────────────
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

    // ── Event handlers — accordion + view controls ────────────────────────────
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

    handleToggleDeps(event) {
        const { workflow } = event.currentTarget.dataset;
        if (this._wfState[workflow]) this._wfState[workflow].showDeps = !this._wfState[workflow].showDeps;
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

    // ── Event handlers — task panel ───────────────────────────────────────────
    handleOpenTask(event) {
        this._openTask(event.currentTarget.dataset.id);
    }

    handleClosePanel() {
        this.selectedTask     = null;
        this.isEditingDueDate = false;
    }

    handleEditDueDateClick() { this.isEditingDueDate = true; }
    handleCancelDueDate()    { this.isEditingDueDate = false; }

    handleDueDateChange(event) {
        if (!this.selectedTask) return;
        const raw     = event.target.value;              // 'YYYY-MM-DD' or ''
        const newDate = raw || null;
        const panelId = this.selectedTask.id;
        updateTaskDueDate({ taskId: panelId, dueDate: newDate })
            .then(() => {
                this.isEditingDueDate = false;
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

    // ── Event handlers — completion modal ─────────────────────────────────────
    handleMarkComplete() {
        if (!this.selectedTask) return;
        this._completionId      = this.selectedTask.id;
        this.completionTaskName = this.selectedTask.name;
        this.completionStatus   = null;
        this.showCompletionModal = true;
    }

    handleStatusChange(event) {
        this.completionStatus = event.detail.value;
    }

    handleCancelCompletion() {
        this.showCompletionModal = false;
        this.completionStatus    = null;
        this._completionId       = null;
    }

    handleConfirmCompletion() {
        completeTask({ taskId: this._completionId, status: this.completionStatus })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title:   `Task marked as ${this.completionStatus}`,
                    variant: 'success'
                }));
                this.showCompletionModal = false;
                this.completionStatus    = null;
                this._completionId       = null;
                this.selectedTask        = null;
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                const msg = err.body && err.body.message ? err.body.message : 'Could not complete task.';
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
            });
    }
}