package com.pm.stack;

import software.amazon.awscdk.*;
import software.amazon.awscdk.services.ec2.Vpc;

public class LocalStack extends Stack {
    private final Vpc vpc;

    public LocalStack(final App scope, final String id, final StackProps props){
        super(scope,id,props);
        this.vpc = createVpc();
    }

    private Vpc createVpc(){
       return Vpc.Builder
               //adds to this stack
                .create(this,"PatientManagementVPC")
                .vpcName("PatientManagementVPC")
               //avalable on 2 zones
                .maxAzs(2)
                .build();
    }

    public static void main(final String[] args) {
        App app = new App(AppProps.builder().outdir("infrastructure/cdk.out").build());
        StackProps props = StackProps.builder()
                .synthesizer(new BootstraplessSynthesizer())
                .build();

        //take that stack adds any props and
        // then convert it into cloud formation template
        //and hit everything into cdk.out
        new LocalStack(app, "localstask", props);
        app.synth();
    }
}
