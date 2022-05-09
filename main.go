/*
 *  *******************************************************************************
 *  * Copyright (c) 2020 Edgeworx, Inc.
 *  *
 *  * This program and the accompanying materials are made available under the
 *  * terms of the Eclipse Public License v. 2.0 which is available at
 *  * http://www.eclipse.org/legal/epl-2.0
 *  *
 *  * SPDX-License-Identifier: EPL-2.0
 *  *******************************************************************************
 *
 */

package main

import (
	"errors"
	"log"
	"os"

	rt "github.com/eclipse-iofog/router/internal/router"

	sdk "github.com/eclipse-iofog/iofog-go-sdk/v3/pkg/microservices"
)

var (
	router *rt.Router
)

func init() {
	router = new(rt.Router)
	router.Config = new(rt.Config)
}

func main() {
	ioFogClient, clientError := sdk.NewDefaultIoFogClient()
	if clientError != nil {
		log.Fatalln(clientError.Error())
	}

	if err := updateConfig(ioFogClient, router.Config); err != nil {
		log.Fatalln(err.Error())
	}

	confChannel := ioFogClient.EstablishControlWsConnection(0)

	exitChannel := make(chan error)
	go router.StartRouter(exitChannel)

	for {
		select {
		case <-exitChannel:
			os.Exit(0)
		case <-confChannel:
			newConfig := new(rt.Config)
			if err := updateConfig(ioFogClient, newConfig); err != nil {
				log.Fatal(err)
			} else {
				router.UpdateRouter(newConfig)
			}
		}
	}
}

func updateConfig(ioFogClient *sdk.IoFogClient, config interface{}) error {
	attemptLimit := 5
	var err error

	for err = ioFogClient.GetConfigIntoStruct(config); err != nil && attemptLimit > 0; attemptLimit-- {
		return err
	}

	if attemptLimit == 0 {
		return errors.New("Update config failed")
	}

	return nil
}
