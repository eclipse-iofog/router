/*
 *  *******************************************************************************
 *  * Copyright (c) 2023 Datasance Teknoloji A.S.
 *  *
 *  * This program and the accompanying materials are made available under the
 *  * terms of the Eclipse Public License v. 2.0 which is available at
 *  * http://www.eclipse.org/legal/epl-2.0
 *  *
 *  * SPDX-License-Identifier: EPL-2.0
 *  *******************************************************************************
 *
 */

package router

import (
	"fmt"

	"github.com/datasance/router/internal/exec"
)

type Listener struct {
	Role string `json:"role"`
	Host string `json:"host"`
	Port int    `json:"port"`
}

type Connector struct {
	Name string `json:"name"`
	Role string `json:"role"`
	Host string `json:"host"`
	Port int    `json:"port"`
}

type Config struct {
	Mode       string      `json:"mode"`
	Name       string      `json:"id"`
	Listeners  []Listener  `json:"listeners"`
	Connectors []Connector `json:"connectors"`
}

type Router struct {
	listeners  map[string]Listener
	connectors map[string]Connector
	Config     *Config
}

func skmanage(args []string) {
	exitChannel := make(chan error)
	go exec.Run(exitChannel, "skmanage", args, []string{})
	for {
		select {
		case <-exitChannel:
			return
		}
	}
}

func listenerName(listener Listener) string {
	return fmt.Sprintf("listener-%s-%s-%d", listener.Role, listener.Host, listener.Port)
}

func connectorName(connector Connector) string {
	return fmt.Sprintf("connector-%s-%s-%s-%d", connector.Name, connector.Role, connector.Host, connector.Port)
}

func deleteEntity(name string) {
	args := []string{
		"delete",
		fmt.Sprintf("--name=%s", name),
	}
	skmanage(args)
}

func (router *Router) createListener(listener Listener) {
	args := []string{
		"create",
		"--type=listener",
		fmt.Sprintf("port=%d", listener.Port),
		fmt.Sprintf("role=%s", listener.Role),
		fmt.Sprintf("host=%s", listener.Host),
		fmt.Sprintf("name=%s", listenerName(listener)),
		fmt.Sprintf("saslMechanisms=ANONYMOUS"),
		fmt.Sprintf("authenticatePeer=no"),
	}
	skmanage(args)
	router.listeners[listenerName(listener)] = listener
}

func (router *Router) createConnector(connector Connector) {
	args := []string{
		"create",
		"--type=connector",
		fmt.Sprintf("port=%d", connector.Port),
		fmt.Sprintf("role=%s", connector.Role),
		fmt.Sprintf("host=%s", connector.Host),
		fmt.Sprintf("name=%s", connectorName(connector)),
	}
	skmanage(args)
	router.connectors[connectorName(connector)] = connector
}

func (router *Router) deleteListener(listener Listener) {
	deleteEntity(listenerName(listener))
	delete(router.listeners, listenerName(listener))
}

func (router *Router) deleteConnector(connector Connector) {
	deleteEntity(connectorName(connector))
	delete(router.connectors, connectorName(connector))
}

func (router *Router) UpdateRouter(newConfig *Config) {
	newListeners := make(map[string]Listener)
	newConnectors := make(map[string]Connector)

	for _, listener := range newConfig.Listeners {
		newListeners[listenerName(listener)] = listener
		if _, ok := router.listeners[listenerName(listener)]; !ok {
			router.createListener(listener)
		}
	}

	for _, connector := range newConfig.Connectors {
		newConnectors[connectorName(connector)] = connector
		if _, ok := router.connectors[connectorName(connector)]; !ok {
			router.createConnector(connector)
		}
	}

	for _, listener := range router.listeners {
		if _, ok := newListeners[listenerName(listener)]; !ok {
			router.deleteListener(listener)
		}
	}

	for _, connector := range router.connectors {
		if _, ok := newConnectors[connectorName(connector)]; !ok {
			router.deleteConnector(connector)
		}
	}

	router.Config = newConfig
}

func (router *Router) GetRouterConfig() string {
	listenersConfig := ""
	for _, listener := range router.listeners {
		listenersConfig += fmt.Sprintf("\\nlistener {\\n  name: %s\\n  role: %s\\n  host: %s\\n  port: %d\\n  saslMechanisms: ANONYMOUS\\n  authenticatePeer: no\\n}", listenerName(listener), listener.Role, listener.Host, listener.Port)
	}

	connectorsConfig := ""
	for _, connector := range router.connectors {
		connectorsConfig += fmt.Sprintf("\\nconnector {\\n  name: %s\\n  host: %s\\n  port: %d\\n  role: %s\\n  saslMechanisms: ANONYMOUS\\n}", connectorName(connector), connector.Host, connector.Port, connector.Role)
	}

	return fmt.Sprintf("router {\\n  mode: %s\\n  id: %s\\n}%s%s", router.Config.Mode, router.Config.Name, listenersConfig, connectorsConfig)
}

func (router *Router) StartRouter(ch chan<- error) {
	router.listeners = make(map[string]Listener)
	router.connectors = make(map[string]Connector)

	for _, listener := range router.Config.Listeners {
		router.listeners[listenerName(listener)] = listener
	}

	for _, connector := range router.Config.Connectors {
		router.connectors[connectorName(connector)] = connector
	}

	routerConfig := router.GetRouterConfig()
	exec.Run(ch, "/home/skrouterd/bin/launch.sh", []string{}, []string{"QDROUTERD_CONF=" + routerConfig})
}
