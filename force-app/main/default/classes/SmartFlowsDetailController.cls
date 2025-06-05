public class SmartFlowsDetailController {

    public String[] recordIds { get; set; }
    public String recordIdString { get; set; }
    public String recordType { get; set; }
    public String orgId {get; set;}
    public String userId {get; set;}

    public SmartFlowsDetailController() {
        this.orgId = UserInfo.getOrganizationId();
        this.userId = UserInfo.getUserId();

        if (ApexPages.currentPage().getParameters().containsKey('id')) {
            this.recordIdString = '["' + ApexPages.currentPage().getParameters().get('id') + '"]';
            this.recordIds = new String[]{
                    ApexPages.currentPage().getParameters().get('id')
            };
            Id id = this.recordIds[0];
            recordType = '' + id.getsobjecttype();
        }
    }
}