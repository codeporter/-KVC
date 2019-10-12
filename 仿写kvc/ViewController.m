//
//  ViewController.m
//  仿写kvc
//
//  Created by coder on 2019/10/9.
//  Copyright © 2019 coder. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+JKKVC.h"

typedef struct Student {
    int age;
    CGFloat height;
    
} Student;


@interface Person : NSObject

@property (nonatomic, assign) int age;

@property (nonatomic, assign) NSString *name;


@end
@implementation Person

@end

@interface ViewController ()
{
    BOOL boolVal;
    char charVal;
    unsigned char unsignedCharVal;
    int intVal;
    unsigned int unsignedIntVal;
}

@property (nonatomic, assign) long longVal;
@property (nonatomic, assign) unsigned long unsignedLongVal;
@property (nonatomic, assign) long long longLongVal;
@property (nonatomic, assign) unsigned long long unsignedLongLongVal;
@property (nonatomic, assign) double doubleVal;
@property (nonatomic, assign) float floatVal;
@property (nonatomic, assign) Student student;

@property (nonatomic, strong) Person *person;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
    [self jk_setValue:@YES forKey:@"boolVal"];
    [self jk_setValue:@('a') forKey:@"charVal"];
    [self jk_setValue:@('b') forKey:@"unsignedCharVal"];
    [self jk_setValue:@10 forKey:@"intVal"];
    [self jk_setValue:@11 forKey:@"unsignedIntVal"];
    [self jk_setValue:@20 forKey:@"longVal"];
    [self jk_setValue:@21 forKey:@"unsignedLongVal"];
    [self jk_setValue:@30 forKey:@"longLongVal"];
    [self jk_setValue:@31 forKey:@"unsignedLongLongVal"];
    [self jk_setValue:@40 forKey:@"doubleVal"];
    [self jk_setValue:@41 forKey:@"floatVal"];
    
    Student stu = {25, 170.0};
    NSValue *stuVal = [NSValue value:&stu withObjCType:@encode(Student)];
    
    [self jk_setValue:stuVal forKey:@"student"];
    [self jk_setValue:[Person new] forKeyPath:@"person"];
    [self jk_setValue:@25 forKeyPath:@"person.age"];
    [self jk_setValue:@"coder" forKeyPath:@"person.name"];
    
    
    NSLog(@"boolVal =%@, charVal = %c, unsignedCharVal = %c, intVal = %@, unsignedIntVal = %@, longVal = %@, unsignedLongVal = %@, longLongVal = %@, unsignedLongLongVal = %@, doubleVal = %@, floatVal = %@",[self jk_valueForKey:@"boolVal"],[[self jk_valueForKey:@"charVal"] charValue],[[self jk_valueForKey:@"unsignedCharVal"] unsignedCharValue],[self jk_valueForKey:@"intVal"],[self jk_valueForKey:@"unsignedIntVal"],[self jk_valueForKey:@"longVal"],[self jk_valueForKey:@"unsignedLongVal"],[self jk_valueForKey:@"longLongVal"],[self jk_valueForKey:@"unsignedLongLongVal"],[self jk_valueForKey:@"doubleVal"],[self jk_valueForKey:@"floatVal"]);
    
    NSValue *studentVal = [self jk_valueForKey:@"student"];
    Student s;
    [studentVal getValue:&s];
    
    
    NSLog(@"student = { age = %d, height = %f }", s.age, s.height);
    NSLog(@"person =  { age = %@, name = %@ }",[self jk_valueForKeyPath:@"person.age"],[self jk_valueForKeyPath:@"person.name"]);
    
    
    NSLog(@"-----------------------------------------------");
}


@end
