//
//  NSManagedObject+FFEntity.m
//  FFCoreData
//
//  Created by Florian Friedrich on 30/05/16.
//  Copyright © 2016 Florian Friedrich. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "NSManagedObject+FFEntity.h"

@implementation NSManagedObject (FFEntity)

#pragma mark - Entity
+ (NSString *)entityName {
    NSString *className = NSStringFromClass(self);
    if ([self shouldRemoveNamespaceInEntityName]) {
        className = [className componentsSeparatedByString:@"."].lastObject;
    }
    return className;
}

#pragma mark - Namespace
static BOOL shouldRemoveNamespace = YES;

+ (BOOL)shouldRemoveNamespaceInEntityName {
    return shouldRemoveNamespace;
}

+ (void)setShouldRemoveNamespaceInEntityName:(BOOL)shouldRemove {
    shouldRemoveNamespace = shouldRemove;
}

@end