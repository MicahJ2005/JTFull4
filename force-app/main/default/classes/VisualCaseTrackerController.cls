/**
 * @File Name          : VisualForceTrackerController.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Brian Ezell (Slalom)
 * @Last Modified On   : 04-04-2022
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    6/2/2020   Revolution Group (Brian Ezell)     Initial Version
**/
public class VisualCaseTrackerController {

    public String mermaidFlow {get;set;}

    public String completedStyles {get;set;}

    private Set<String> completedTasksAndEvents;

    public VisualCaseTrackerController() {
        String currentId = ApexPages.currentPage().getParameters().get('id');
        completedTasksAndEvents = new Set<String>();
        mermaidFlow  = getMermaidForTemplate(currentId);
    }

    public String getMermaidForTemplate(String id) {

        completedStyles = 'completed';

        List<Case> allCases = HelperFunctions.getAssociatedCases(id);

        Date thisDate = Date.today();
        //Determine which tasks/events are completed.
        //This changes some display options
        for(Case c : allCases) {
            for(Task t : c.Tasks) {
                if(t.Is_Completed__c) {
                    completedTasksAndEvents.add(t.Id);
                }
            }
            for(Event e : c.Events) {
                if(e.Is_Completed__c) {
                    completedTasksAndEvents.add(e.Id);
                }
            }
        }

        //Get the top level master template, then work
        //downwards
        Case masterCase;
        for(Case c : allCases) {
            if(c.Top_Level_Task_Tracker_Case__c == c.Id) {
                masterCase = c;
                break;
            }
        }

        if(masterCase.Status != 'Completed') {
            completedStyles += ' hidden';
        }

        List<String> flowList = new List<String>();

        flowList.add('graph TB');
        //flowList.add('graph LR');


        flowList.addAll(getCaseFlow(allCases, masterCase));

        //If we don't add dependencies last, if a dependency is referenced
        //before it is defined, it will show up in the dependency case
        //rather than the correct case
        for(Case c : allCases) {
            for(Task_Tracker_Task_Dependency__c d : c.Case_Dependencies__r) {
                flowList.add(d.Task_Depends_On_Id__c + '-->' + d.Task_Id__c);
            }
        }

        return String.join(flowList, '\n\r');
    }

    private List<String> getCaseFlow(List<Case> allCases, Case currentCase) {
        List<String> flowSteps = new List<String>();

        List<Case> childCases = new List<Case>();
        for(Case c : allCases) {
            if(c.ParentId == currentCase.Id) {
                childCases.add(c);
            }
        }

        flowSteps.add('subgraph ' + currentCase.Subject);

        for(Task t : currentCase.Tasks) {
            //If this is completed put a asterisk next to it
            if(t.Is_Completed__c) {
                flowSteps.add(t.Id + '(' + cleanStringForMermaid(t.Subject) + '*)');
            } else {
                flowSteps.add(t.Id + '(' + cleanStringForMermaid(t.Subject) + ')');
            }
        }
        Date completedDate = Date.today();
        for(Event e : currentCase.Events) {

            //if the event took place already, put an asterisk
            //next to it.
            if(e.Is_Completed__c) {
                flowSteps.add(e.Id + '[/' + cleanStringForMermaid(e.Subject) + '*/]');
            } else {
                flowSteps.add(e.Id + '[/' + cleanStringForMermaid(e.Subject) + '/]');
            }
        }
        for(Case c : childCases) {
            flowSteps.addAll(getCaseFlow(allCases, c));
        }

        flowSteps.add('end');
        return flowSteps;
    }

    private static String cleanStringForMermaid(String str) {
        if (str == null) return null;
        return str.replace('(', '**').
            replace(')', '**').
            replace(';', ' ');
    }
}